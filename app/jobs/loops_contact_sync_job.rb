class LoopsContactSyncJob < ApplicationJob
  include LoopsRetryable

  def perform(user_id, intent, previously_consented: nil)
    user = User.find_by(id: user_id)
    return unless user

    LoopsContactSynchronizer.new.sync(user, intent: intent, previously_consented: previously_consented)
  end
end
