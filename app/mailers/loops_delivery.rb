class LoopsDelivery
  class MissingHeader < StandardError; end

  class InvalidDataVariables < StandardError; end
  class InvalidRecipient < StandardError; end
  class InvalidAttachment < StandardError; end

  BILLING_TRANSACTIONAL_KEYS = %i[
    receipt
    refund
    subscription_renewing
    payment_action_required
    payment_failed
    subscription_trial_will_end
    subscription_trial_ended
  ].freeze

  def initialize(values)
    @settings = values
  end

  def deliver!(mail)
    transactional_id = mail.header["X-Loops-Transactional-Id"]&.value
    raise MissingHeader, "X-Loops-Transactional-Id header is required" if transactional_id.blank?

    raw_data_variables = mail.header["X-Loops-Data-Variables"]&.value
    raise MissingHeader, "X-Loops-Data-Variables header is required" if raw_data_variables.blank?

    data_variables = parse_data_variables(raw_data_variables)
    idempotency_seed = billing_idempotency_seed(mail, transactional_id)
    attachments = loops_attachments(mail)

    client = LoopsClient.client
    recipients(mail).each do |recipient|
      client.send_transactional(
        email: recipient,
        transactional_id: transactional_id,
        data_variables: data_variables,
        idempotency_seed: idempotency_seed,
        attachments: attachments
      )
    end
  end

  private

  def parse_data_variables(raw_data_variables)
    data_variables = JSON.parse(raw_data_variables)
  rescue JSON::ParserError => e
    raise InvalidDataVariables, "X-Loops-Data-Variables is not valid JSON: #{e.message}"
  else
    unless data_variables.is_a?(Hash)
      raise InvalidDataVariables, "X-Loops-Data-Variables must be a JSON object"
    end
    data_variables
  end

  def billing_idempotency_seed(mail, transactional_id)
    return unless billing_transactional_id?(transactional_id)

    seed = mail.header["X-Loops-Idempotency-Seed"]&.value
    raise MissingHeader, "X-Loops-Idempotency-Seed header is required for billing messages" if seed.blank?

    seed
  end

  def billing_transactional_id?(transactional_id)
    BILLING_TRANSACTIONAL_KEYS.map { |key| Rails.application.config_for(:loops).transactional.fetch(key) }.include?(transactional_id)
  end

  def recipients(mail)
    Array(mail.to).map do |recipient|
      address = Mail::Address.new(recipient).address
      raise InvalidRecipient, "mail recipient is not a valid email address" if address.blank?

      address
    rescue Mail::Field::ParseError
      raise InvalidRecipient, "mail recipient is not a valid email address"
    end.uniq
  end

  def loops_attachments(mail)
    mail.attachments.map do |attachment|
      data = attachment.decoded
      raise InvalidAttachment, "attachment data is missing" if data.blank?

      {
        filename: attachment.filename,
        contentType: attachment.mime_type,
        data: Base64.strict_encode64(data)
      }
    rescue => e
      raise e if e.is_a?(InvalidAttachment)

      raise InvalidAttachment, "attachment could not be encoded: #{e.message}"
    end
  end
end
