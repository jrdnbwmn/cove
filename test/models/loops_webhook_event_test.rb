require "test_helper"

class LoopsWebhookEventTest < ActiveSupport::TestCase
  test "webhook_id is unique" do
    duplicate = LoopsWebhookEvent.new(
      webhook_id: loops_webhook_events(:one).webhook_id,
      event_name: "email.hardBounced",
      payload: {}
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  test "prunable returns only events older than the retention window" do
    assert_equal [loops_webhook_events(:stale)], LoopsWebhookEvent.prunable.to_a
  end

  test "unprocessed returns only events without processed_at" do
    assert_equal [loops_webhook_events(:unprocessed)], LoopsWebhookEvent.unprocessed.to_a
  end

  test "processed! stamps processed_at" do
    event = loops_webhook_events(:unprocessed)

    assert_nil event.processed_at
    event.processed!

    assert_predicate event.reload.processed_at, :present?
  end

  test "parse_event_time handles seconds" do
    seconds = 1_700_000_000
    assert_equal Time.at(seconds), LoopsWebhookEvent.parse_event_time(seconds)
  end

  test "parse_event_time handles milliseconds" do
    milliseconds = 1_700_000_000_000
    assert_equal Time.at(1_700_000_000), LoopsWebhookEvent.parse_event_time(milliseconds)
  end

  test "parse_event_time handles nil" do
    assert_nil LoopsWebhookEvent.parse_event_time(nil)
  end
end
