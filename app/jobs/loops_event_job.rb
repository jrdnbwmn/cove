class LoopsEventJob < ApplicationJob
  include LoopsRetryable

  queue_with_priority 10

  def perform(user_id, event_name)
    user = User.find_by(id: user_id)
    return unless user

    LoopsEventEmitter.new.emit(user, event_name)
  end
end
