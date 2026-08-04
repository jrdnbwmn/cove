module LoopsRetryable
  extend ActiveSupport::Concern

  included do
    retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
      Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
      Errno::ECONNRESET, wait: :polynomially_longer
  end
end
