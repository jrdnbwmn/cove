require "test_helper"

class LoopsContactLifecycleTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { clear_enqueued_jobs }

  test "unchecked registration does not enqueue contact synchronization" do
    user = build_user(marketing_opt_in: "0")

    assert_no_enqueued_jobs only: LoopsContactSyncJob do
      user.save!
    end
  end

  test "checked registration enqueues an opt-in after commit" do
    user = build_user(marketing_opt_in: "1")

    assert_enqueued_jobs 1, only: LoopsContactSyncJob do
      user.save!
    end
    assert_equal [user.id, "opt_in"], enqueued_jobs.last.fetch(:args)
  end

  test "settings opt-in and app opt-out enqueue their exact intents" do
    user = users(:one)

    assert_enqueued_with(job: LoopsContactSyncJob, args: [user.id, "opt_in"]) do
      user.grant_marketing_consent(source: "settings")
    end

    assert_enqueued_with(job: LoopsContactSyncJob, args: [user.id, "opt_out"]) do
      user.withdraw_marketing_consent(reason: "user_app")
    end
  end

  test "protected and Loops-originated consent changes do not enqueue contact work" do
    user = users(:marketing_unsubscribed)
    user.update!(marketing_opt_out_reason: "user_loops")
    clear_enqueued_jobs

    assert_no_enqueued_jobs only: LoopsContactSyncJob do
      user.update!(first_name: "Unchanged")
    end

    user = users(:marketing_subscribed)
    user.update!(marketing_opt_in_source: "loops")
    assert_no_enqueued_jobs only: LoopsContactSyncJob do
      user.update!(marketing_opt_in_at: Time.current)
    end
  end

  test "email changes only enqueue maintenance for users who previously consented" do
    consenting = users(:marketing_subscribed)
    never_consented = users(:one)

    assert_enqueued_with(job: LoopsContactSyncJob, args: [consenting.id, "email_change"]) do
      consenting.update!(email: "changed-consenting@example.com")
    end

    assert_no_enqueued_jobs only: LoopsContactSyncJob do
      never_consented.update!(email: "changed-never@example.com")
    end
  end

  test "a simultaneous opt-in and email change does not enqueue redundant work" do
    user = users(:one)

    assert_enqueued_jobs 1, only: LoopsContactSyncJob do
      user.assign_attributes(email: "opted-in@example.com")
      user.grant_marketing_consent(source: "settings")
    end
  end

  test "destruction enqueues a plain string identifier for every user" do
    user = users(:one)

    assert_enqueued_with(job: LoopsContactDeletionJob, args: [user.id.to_s]) do
      user.destroy!
    end
  end

  test "lifecycle jobs reload current state and deletion jobs delegate their snapshot" do
    user = users(:marketing_subscribed)
    synchronizer = RecordingSynchronizer.new
    LoopsContactSynchronizer.stub(:new, synchronizer) do
      LoopsContactSyncJob.perform_now(user.id, "opt_in")
    end
    assert_equal [[user, "opt_in"]], synchronizer.sync_calls

    deletion_synchronizer = RecordingSynchronizer.new
    LoopsContactSynchronizer.stub(:new, deletion_synchronizer) do
      LoopsContactDeletionJob.perform_now(user.id.to_s)
    end
    assert_equal [user.id.to_s], deletion_synchronizer.deletion_calls
  end

  test "contact jobs retry transient failures and leave permanent failures unhandled" do
    [LoopsContactSyncJob, LoopsContactDeletionJob].each do |job|
      retryable = job.rescue_handlers.filter_map { |exception_name, _| exception_name.safe_constantize }

      assert_includes retryable, LoopsClient::RateLimit
      assert_includes retryable, LoopsClient::InternalError
      assert_includes retryable, Net::OpenTimeout
      assert_includes retryable, Net::ReadTimeout
      assert_includes retryable, SocketError
      assert_includes retryable, Errno::ECONNREFUSED
      assert_includes retryable, Errno::ECONNRESET
      assert_not_includes retryable, LoopsClient::BadRequest
      assert_not_includes retryable, LoopsClient::Conflict
    end
  end

  private

  class RecordingSynchronizer
    attr_reader :sync_calls, :deletion_calls

    def initialize
      @sync_calls = []
      @deletion_calls = []
    end

    def sync(user, intent:)
      sync_calls << [user, intent]
    end

    def delete(user_id)
      deletion_calls << user_id
    end
  end

  def build_user(marketing_opt_in:)
    User.new(
      email: "lifecycle-#{SecureRandom.hex(4)}@example.com",
      first_name: "Lifecycle",
      last_name: "Test",
      password: UNIQUE_PASSWORD,
      password_confirmation: UNIQUE_PASSWORD,
      terms_of_service: "1",
      marketing_opt_in:
    )
  end
end
