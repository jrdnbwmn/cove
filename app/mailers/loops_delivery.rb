class LoopsDelivery
  class MissingHeader < StandardError; end

  class InvalidDataVariables < StandardError; end

  def initialize(values)
    @settings = values
  end

  def deliver!(mail)
    transactional_id = mail.header["X-Loops-Transactional-Id"]&.value
    raise MissingHeader, "X-Loops-Transactional-Id header is required" if transactional_id.blank?

    raw_data_variables = mail.header["X-Loops-Data-Variables"]&.value
    raise MissingHeader, "X-Loops-Data-Variables header is required" if raw_data_variables.blank?

    data_variables = parse_data_variables(raw_data_variables)

    client = LoopsClient.client
    Array(mail.to).each do |recipient|
      client.send_transactional(
        email: recipient,
        transactional_id: transactional_id,
        data_variables: data_variables
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
end
