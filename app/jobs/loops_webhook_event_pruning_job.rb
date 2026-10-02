# AIDEV-NOTE: Only processed rows are pruned. An event still unprocessed after the sweep's 7-day window has failed
# permanently, so it is kept (with its Honeybadger report) for investigation rather than silently deleted.
class LoopsWebhookEventPruningJob < ApplicationJob
  def perform
    LoopsWebhookEvent.prunable.where.not(processed_at: nil).delete_all
  end
end
