class LoopsContactDeletionJob < ApplicationJob
  retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
    Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
    Errno::ECONNRESET, wait: :polynomially_longer

  def perform(user_id)
    LoopsContactSynchronizer.new.delete(user_id)
  end
end
