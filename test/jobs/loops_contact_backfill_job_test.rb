require "test_helper"

class LoopsContactBackfillJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class RecordingClient
    attr_reader :throttler, :updates

    def initialize(throttler:)
      @throttler = throttler
      @updates = []
    end

    def update_contact(**attributes)
      throttler.call
      updates << attributes
    end
  end

  class RecordingSynchronizer
    attr_reader :syncs

    def initialize(client: nil, ready: true, &before_sync)
      @client = client
      @ready = ready
      @before_sync = before_sync
      @syncs = []
    end

    def ensure_backfill_ready!
      raise LoopsContactSynchronizer::ProductionRequired, "production required" unless @ready
    end

    def sync(user, intent:)
      @before_sync&.call(user)
      return unless user.marketing_subscribed?

      @client&.update_contact(user_id: user.id.to_s)
      syncs << [user, intent]
    end
  end

  setup { clear_enqueued_jobs }

  test "invalid configuration fails before constructing a client" do
    readiness = RecordingSynchronizer.new(ready: false)
    job = LoopsContactBackfillJob.new

    job.stub(:build_synchronizer, ->(client: nil) { client ? flunk("client-backed synchronizer must not be built") : readiness }) do
      job.stub(:build_client, ->(throttler:) { flunk("client must not be constructed") }) do
        assert_raises(LoopsContactSynchronizer::ProductionRequired) { job.perform }
      end
    end
  end

  test "processes only consenting candidates in ascending cursor-exclusive order" do
    first = users(:marketing_subscribed)
    second = create_subscribed_user("backfill-second@example.com")
    skipped = users(:marketing_unsubscribed)
    synchronizer = RecordingSynchronizer.new

    perform_with(synchronizer:, cursor: first.id - 1)

    assert_equal [first.id, second.id], synchronizer.syncs.map { |user, _| user.id }
    assert_equal [:opt_in, :opt_in], synchronizer.syncs.map(&:last)
    assert_not_includes synchronizer.syncs.map { |user, _| user.id }, skipped.id
  end

  test "reloads candidates and skips consent withdrawn before its turn" do
    first = users(:marketing_subscribed)
    second = create_subscribed_user("backfill-withdrawn@example.com")
    original_second = second
    synchronizer = RecordingSynchronizer.new do |user|
      second.withdraw_marketing_consent(reason: "user_app") if user.id == first.id
    end

    perform_with(synchronizer:)

    assert_equal [first.id], synchronizer.syncs.map { |user, _| user.id }
    refute_same original_second, synchronizer.syncs.first.first
  end

  test "reuses one throttled client and pauses before every request" do
    user = users(:marketing_subscribed)
    pauses = []
    client = nil
    synchronizer = nil
    job = LoopsContactBackfillJob.new

    job.stub(:build_synchronizer, ->(client: nil) { client ? synchronizer = RecordingSynchronizer.new(client:) : RecordingSynchronizer.new }) do
      job.stub(:build_client, ->(throttler:) { client = RecordingClient.new(throttler:) }) do
        job.stub(:pause, ->(seconds) { pauses << seconds }) { job.perform(user.id - 1) }
      end
    end

    assert_equal [0.2], pauses
    assert_equal 1, client.updates.size
    assert_equal [[user.id, :opt_in]], synchronizer.syncs.map { |synced_user, intent| [synced_user.id, intent] }
  end

  test "a complete batch enqueues its last examined ID only after all users succeed" do
    first = users(:marketing_subscribed)
    second = create_subscribed_user("backfill-next@example.com")
    synchronizer = RecordingSynchronizer.new

    assert_enqueued_with(job: LoopsContactBackfillJob, args: [second.id]) do
      perform_with(synchronizer:, cursor: first.id - 1, candidate_ids: Array.new(99, first.id) + [second.id])
    end
  end

  test "an empty batch completes without enqueueing duplicate work" do
    synchronizer = RecordingSynchronizer.new

    assert_no_enqueued_jobs(only: LoopsContactBackfillJob) { perform_with(synchronizer:, cursor: User.maximum(:id)) }
    assert_empty synchronizer.syncs
  end

  test "transient failures schedule a retry without advancing the cursor" do
    user = users(:marketing_subscribed)
    synchronizer = RecordingSynchronizer.new do |_user|
      raise LoopsClient::RateLimit, "slow down"
    end
    job = LoopsContactBackfillJob.new(user.id - 1)

    assert_enqueued_with(job: LoopsContactBackfillJob, args: [user.id - 1]) do
      job.stub(:build_synchronizer, ->(client: nil) { client ? synchronizer : RecordingSynchronizer.new }) do
        job.stub(:build_client, ->(throttler:) { RecordingClient.new(throttler:) }) do
          job.stub(:pause, ->(_seconds) {}) { job.perform_now }
        end
      end
    end
  end

  test "declares the lifecycle transient retry policy" do
    retryable = LoopsContactBackfillJob.rescue_handlers.filter_map { |exception_name, _| exception_name.safe_constantize }

    [LoopsClient::RateLimit, LoopsClient::InternalError, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET].each do |exception|
      assert_includes retryable, exception
    end
  end

  private

  def perform_with(synchronizer:, cursor: nil, job: LoopsContactBackfillJob.new, candidate_ids: nil)
    job.stub(:build_synchronizer, ->(client: nil) { client ? synchronizer : RecordingSynchronizer.new }) do
      job.stub(:build_client, ->(throttler:) { RecordingClient.new(throttler:) }) do
        job.stub(:pause, ->(_seconds) {}) do
          candidate_ids ? job.stub(:candidate_ids, candidate_ids) { job.perform(cursor) } : job.perform(cursor)
        end
      end
    end
  end

  def create_subscribed_user(email)
    user = User.new(
      email: email,
      first_name: "Backfill",
      last_name: "Test",
      password: UNIQUE_PASSWORD,
      password_confirmation: UNIQUE_PASSWORD,
      terms_of_service: "1",
      marketing_opt_in_at: Time.current,
      marketing_opt_in_source: "settings"
    )
    user.save!
    user
  end
end
