class LoopsMailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
    Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer
end
