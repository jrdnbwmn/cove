class LoopsWebhookEventPruningJob < ApplicationJob
  def perform
    LoopsWebhookEvent.prunable.delete_all
  end
end
