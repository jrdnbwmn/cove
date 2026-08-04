class LoopsContactDeletionJob < ApplicationJob
  include LoopsRetryable

  def perform(user_id)
    LoopsContactSynchronizer.new.delete(user_id)
  end
end
