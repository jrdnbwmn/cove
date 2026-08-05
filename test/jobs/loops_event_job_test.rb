require "test_helper"

class LoopsEventJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class RecordingEmitter
    attr_reader :emissions

    def initialize
      @emissions = []
    end

    def emit(user, event_name)
      emissions << [user, event_name]
    end
  end

  setup { clear_enqueued_jobs }

  test "performing with a valid user id calls the emitter with that user and event name" do
    user = users(:marketing_subscribed)
    emitter = RecordingEmitter.new

    LoopsEventEmitter.stub(:new, emitter) do
      LoopsEventJob.new.perform(user.id, "user_signed_up")
    end

    assert_equal [[user, "user_signed_up"]], emitter.emissions
  end

  test "performing with a deleted or unknown user id is a no-op and constructs no emitter" do
    unknown_id = User.maximum(:id).to_i + 1

    LoopsEventEmitter.stub(:new, -> { flunk "emitter must not be constructed" }) do
      assert_nil LoopsEventJob.new.perform(unknown_id, "user_signed_up")
    end
  end

  test "declares the lifecycle transient retry policy" do
    retryable = LoopsEventJob.rescue_handlers.filter_map { |exception_name, _| exception_name.safe_constantize }

    [LoopsClient::RateLimit, LoopsClient::InternalError, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET].each do |exception|
      assert_includes retryable, exception
    end
  end
end
