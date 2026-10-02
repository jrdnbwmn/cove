module LoopsRetryable
  extend ActiveSupport::Concern

  included do
    # AIDEV-NOTE: Solid Queue runs lower numbers first, so marketing sync work
    # yields to mail and Pay jobs at priority 0.
    queue_with_priority 10

    retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
      Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
      Errno::ECONNRESET, wait: :polynomially_longer
  end
end
