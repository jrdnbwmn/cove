class LoopsClient < ApplicationClient
  BASE_URI = "https://app.loops.so/api"

  class BadRequest < Error; end
  class Conflict < Error; end
  class PayloadTooLarge < Error; end

  def self.client
    new(token: Rails.application.credentials.dig(:loops, :api_key))
  end

  def open_timeout = 2

  def read_timeout = 5

  def send_transactional(email:, transactional_id:, data_variables: {})
    post "/v1/transactional",
      body: {
        email: email,
        transactionalId: transactional_id,
        addToAudience: false,
        dataVariables: data_variables
      },
      headers: {"Idempotency-Key" => idempotency_key(transactional_id, email, data_variables)}
    true
  rescue Conflict
    Rails.logger.info("[Loops] duplicate transactional send suppressed for #{transactional_id}")
    true
  end

  # AIDEV-NOTE: Do not include retry-varying values such as Time.current or SecureRandom in data_variables.
  def idempotency_key(transactional_id, email, data_variables)
    Digest::SHA256.hexdigest([
      transactional_id,
      email,
      data_variables.transform_keys(&:to_s).sort.to_h.to_json
    ].join(":"))
  end

  def handle_response(response)
    case response.code
    when "400"
      raise self.class::BadRequest, response.body
    when "409"
      raise self.class::Conflict, response.body
    when "413"
      raise self.class::PayloadTooLarge, response.body
    else
      super
    end
  end
end
