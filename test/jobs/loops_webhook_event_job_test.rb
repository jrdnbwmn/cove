require "test_helper"

class LoopsWebhookEventJobTest < ActiveJob::TestCase
  test "processes an unprocessed event and stamps processed_at" do
    event = loops_webhook_events(:unprocessed)
    user = users(:marketing_subscribed)
    event.update!(payload: {"eventName" => event.event_name, "contactIdentity" => {"userId" => user.id.to_s, "email" => user.email}})

    LoopsWebhookEventJob.perform_now(event.id)

    assert_equal "hard_bounce", user.reload.marketing_opt_out_reason
    assert_predicate event.reload.processed_at, :present?
  end

  test "skips an already-processed event without calling the processor" do
    event = loops_webhook_events(:one)

    LoopsWebhookEventProcessor.stub(:new, -> { flunk "processor must not be constructed" }) do
      assert_nothing_raised { LoopsWebhookEventJob.perform_now(event.id) }
    end
  end

  test "a missing id is a no-op" do
    assert_nothing_raised do
      LoopsWebhookEventJob.perform_now(-1)
    end
  end

  test "a processor exception leaves processed_at nil and re-raises" do
    event = loops_webhook_events(:unprocessed)
    failing_processor = Object.new
    def failing_processor.call(_event)
      raise StandardError, "boom"
    end

    LoopsWebhookEventProcessor.stub(:new, failing_processor) do
      assert_raises(StandardError) do
        LoopsWebhookEventJob.perform_now(event.id)
      end
    end

    assert_nil event.reload.processed_at
  end
end
