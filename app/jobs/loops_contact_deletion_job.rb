class LoopsContactDeletionJob < ApplicationJob
  include LoopsRetryable

  queue_with_priority 10

  def perform(user_id)
    LoopsContactSynchronizer.new.delete(user_id)
  end
end
