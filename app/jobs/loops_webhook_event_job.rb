# AIDEV-NOTE: Active Job retries failed event processing. LoopsWebhookEventSweepJob's
# daily sweep covers rows whose job was never enqueued; processed_at makes retries safe.
class LoopsWebhookEventJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(event_id)
    event = LoopsWebhookEvent.find_by(id: event_id)
    return unless event
    return if event.processed_at

    LoopsWebhookEventProcessor.new.call(event)
    event.processed!
  end
end
