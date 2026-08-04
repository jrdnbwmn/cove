class LoopsContactSyncJob < ApplicationJob
  retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
    Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
    Errno::ECONNRESET, wait: :polynomially_longer

  def perform(user_id, intent)
    user = User.find_by(id: user_id)
    return unless user

    LoopsContactSynchronizer.new.sync(user, intent: intent)
  end
end
