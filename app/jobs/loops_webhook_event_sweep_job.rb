# AIDEV-NOTE: If enqueueing fails after a webhook row is saved, Loops retries
# the request but deduplication skips the row. This bounded window requeues
# stranded rows without endlessly retrying permanently failing events.
class LoopsWebhookEventSweepJob < ApplicationJob
  def perform
    LoopsWebhookEvent.unprocessed.where(created_at: 7.days.ago..1.hour.ago).find_each do |event|
      LoopsWebhookEventJob.perform_later(event.id)
    end
  end
end
