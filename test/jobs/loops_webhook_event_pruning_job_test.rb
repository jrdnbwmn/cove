require "test_helper"

class LoopsWebhookEventPruningJobTest < ActiveJob::TestCase
  test "deletes events older than the retention window" do
    stale_id = loops_webhook_events(:stale).id

    LoopsWebhookEventPruningJob.perform_now

    assert_not LoopsWebhookEvent.exists?(stale_id)
  end

  test "keeps events inside the retention window" do
    LoopsWebhookEventPruningJob.perform_now

    assert LoopsWebhookEvent.exists?(loops_webhook_events(:one).id)
    assert LoopsWebhookEvent.exists?(loops_webhook_events(:unprocessed).id)
  end

  test "is safe to run against an empty table" do
    LoopsWebhookEvent.delete_all

    assert_nothing_raised { LoopsWebhookEventPruningJob.perform_now }
  end
end
