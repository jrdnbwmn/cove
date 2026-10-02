class LoopsWebhookEventPruningJob < ApplicationJob
  def perform
    LoopsWebhookEvent.prunable.where.not(processed_at: nil).delete_all
  end
end
