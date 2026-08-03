require "test_helper"

class LoopsMailDeliveryJobTest < ActiveSupport::TestCase
  test "uses the custom mail delivery job" do
    assert LoopsMailDeliveryJob < ActionMailer::MailDeliveryJob
    assert_equal LoopsMailDeliveryJob, ActionMailer::Base.delivery_job
  end

  test "retries transient Loops and network failures" do
    retryable_exceptions = LoopsMailDeliveryJob.rescue_handlers.filter_map do |exception_name, _handler|
      exception_name.safe_constantize
    end

    assert_includes retryable_exceptions, LoopsClient::RateLimit
    assert_includes retryable_exceptions, LoopsClient::InternalError
    assert_includes retryable_exceptions, Net::OpenTimeout
    assert_includes retryable_exceptions, Net::ReadTimeout
  end
end
