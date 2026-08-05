# AIDEV-NOTE: no LoopsRetryable here — there are no HTTP calls in this job,
# so standard ActiveJob retry semantics apply. processed_at stays nil on
# failure, leaving the row retryable by a subsequent job attempt.
class LoopsWebhookEventJob < ApplicationJob
  def perform(event_id)
    event = LoopsWebhookEvent.find_by(id: event_id)
    return unless event
    return if event.processed_at

    LoopsWebhookEventProcessor.new.call(event)
    event.processed!
  end
end
