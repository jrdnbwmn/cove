require "test_helper"

class LoopsWebhookEventSweepJobTest < ActiveJob::TestCase
  test "stranded webhook events are queued for processing again" do
    stranded = loops_webhook_events(:unprocessed)
    stranded.update_columns(created_at: 2.hours.ago, processed_at: nil)
    recent = LoopsWebhookEvent.create!(webhook_id: "wh_recent", event_name: "contact.unsubscribed", event_time: Time.current, payload: {}, processed_at: nil, created_at: 5.minutes.ago)
    processed = loops_webhook_events(:one)
    processed.update_columns(created_at: 2.hours.ago)
    old = loops_webhook_events(:old_unprocessed)

    assert_enqueued_with(job: LoopsWebhookEventJob, args: [stranded.id]) do
      assert_enqueued_jobs 1, only: LoopsWebhookEventJob do
        LoopsWebhookEventSweepJob.perform_now
      end
    end

    queued_ids = enqueued_jobs.select { |job| job[:job] == LoopsWebhookEventJob }.map { |job| job[:args].first }
    assert_not_includes queued_ids, recent.id
    assert_not_includes queued_ids, processed.id
    assert_not_includes queued_ids, old.id
  end
end
