class LoopsClient < ApplicationClient
  BASE_URI = "https://app.loops.so/api"

  class BadRequest < Error; end
  class Conflict < Error; end
  class PayloadTooLarge < Error; end

  NO_OP_THROTTLER = -> {}

  CONTACT_RESERVED_FIELDS = %w[email userId subscribed mailingLists].freeze
  EVENT_RESERVED_FIELDS = %w[email userId eventName eventProperties mailingLists].freeze

  attr_reader :throttler

  def initialize(auth: nil, basic_auth: nil, token: nil, throttler: nil)
    super(auth: auth, basic_auth: basic_auth, token: token)
    @throttler = throttler || NO_OP_THROTTLER
  end

  def self.client(throttler: nil)
    new(token: Rails.application.credentials.dig(:loops, :api_key), throttler: throttler)
  end

  def open_timeout = 2

  def read_timeout = 5

  def create_contact(email:, user_id: nil, subscribed: nil, mailing_lists: {}, contact_properties: {})
    raise ArgumentError, "email is required" if email.blank?

    body = contact_write_body(email: email, user_id: user_id, subscribed: subscribed, mailing_lists: mailing_lists, contact_properties: contact_properties)

    marketing_request { post("/v1/contacts/create", body: body).parsed_body }
  end

  def update_contact(email: nil, user_id: nil, subscribed: nil, mailing_lists: {}, contact_properties: {})
    validate_identifiers!(email: email, user_id: user_id, require: :at_least_one)

    body = contact_write_body(email: email, user_id: user_id, subscribed: subscribed, mailing_lists: mailing_lists, contact_properties: contact_properties)

    marketing_request { put("/v1/contacts/update", body: body).parsed_body }
  end

  def find_contact(email: nil, user_id: nil)
    validate_identifiers!(email: email, user_id: user_id, require: :exactly_one)

    marketing_request { get("/v1/contacts/find", query: identifier_query(email: email, user_id: user_id)).parsed_body }
  end

  def delete_contact(email: nil, user_id: nil)
    validate_identifiers!(email: email, user_id: user_id, require: :exactly_one)

    marketing_request { post("/v1/contacts/delete", body: identifier_query(email: email, user_id: user_id)).parsed_body }
  end

  def suppression_status(email: nil, user_id: nil)
    validate_identifiers!(email: email, user_id: user_id, require: :exactly_one)

    marketing_request { get("/v1/contacts/suppression", query: identifier_query(email: email, user_id: user_id)).parsed_body }
  end

  def remove_suppression(email: nil, user_id: nil)
    validate_identifiers!(email: email, user_id: user_id, require: :exactly_one)

    marketing_request { delete("/v1/contacts/suppression", query: identifier_query(email: email, user_id: user_id)).parsed_body }
  end

  def list_mailing_lists
    marketing_request { get("/v1/lists").parsed_body }
  end

  def send_event(event_name:, email: nil, user_id: nil, event_properties: {}, mailing_lists: {}, contact_properties: {}, idempotency_key: nil)
    raise ArgumentError, "event_name is required" if event_name.blank?
    validate_identifiers!(email: email, user_id: user_id, require: :at_least_one)

    body = event_body(event_name: event_name, email: email, user_id: user_id, event_properties: event_properties, mailing_lists: mailing_lists, contact_properties: contact_properties)
    headers = idempotency_key.nil? ? {} : {"Idempotency-Key" => idempotency_key}

    throttler.call
    begin
      post("/v1/events/send", body: body, headers: headers)
    rescue Conflict
      return true
    end
    true
  end

  def send_transactional(email:, transactional_id:, data_variables: {}, idempotency_seed: nil, attachments: [])
    body = {
      email: email,
      transactionalId: transactional_id,
      addToAudience: false,
      dataVariables: data_variables
    }
    body[:attachments] = attachments if attachments.present?

    post "/v1/transactional",
      body: body,
      headers: {"Idempotency-Key" => idempotency_key(transactional_id, email, data_variables, idempotency_seed)}
    true
  rescue Conflict
    Rails.logger.info("[Loops] duplicate transactional send suppressed for #{transactional_id}")
    true
  end

  # AIDEV-NOTE: Do not include retry-varying values such as Time.current or SecureRandom in data_variables.
  def idempotency_key(transactional_id, email, data_variables, idempotency_seed = nil)
    key_parts = [transactional_id, email]
    key_parts << (idempotency_seed.presence || data_variables.transform_keys(&:to_s).sort.to_h.to_json)

    Digest::SHA256.hexdigest(key_parts.join(":"))
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

  private

  def marketing_request
    throttler.call
    yield
  end

  def validate_identifiers!(email:, user_id:, require:)
    present = [email, user_id].map(&:presence)

    case require
    when :at_least_one
      raise ArgumentError, "email or user_id is required" if present.compact.empty?
    when :exactly_one
      raise ArgumentError, "exactly one of email or user_id is required" if present.compact.size != 1
    end
  end

  def identifier_query(email:, user_id:)
    email.present? ? {email: email} : {userId: user_id}
  end

  def serialize_mailing_lists(mailing_lists)
    mailing_lists.each_with_object({}) do |(list_id, subscribed), result|
      unless subscribed == true || subscribed == false
        raise ArgumentError, "mailing list membership must be true or false"
      end
      result[list_id.to_s] = subscribed
    end
  end

  def merge_contact_properties(body, contact_properties, reserved_fields = CONTACT_RESERVED_FIELDS)
    cleaned = contact_properties.reject { |key, _| reserved_fields.include?(key.to_s) }
    body.merge(cleaned)
  end

  def contact_write_body(email:, user_id:, subscribed:, mailing_lists:, contact_properties:)
    body = {}
    body[:email] = email if email.present?
    body[:userId] = user_id if user_id.present?
    body[:subscribed] = subscribed unless subscribed.nil?

    serialized_lists = serialize_mailing_lists(mailing_lists)
    body[:mailingLists] = serialized_lists if serialized_lists.present?

    merge_contact_properties(body, contact_properties)
  end

  def event_body(event_name:, email:, user_id:, event_properties:, mailing_lists:, contact_properties:)
    body = {}
    body[:email] = email if email.present?
    body[:userId] = user_id if user_id.present?
    body[:eventName] = event_name
    body[:eventProperties] = event_properties

    serialized_lists = serialize_mailing_lists(mailing_lists)
    body[:mailingLists] = serialized_lists if serialized_lists.present?

    merge_contact_properties(body, contact_properties, EVENT_RESERVED_FIELDS)
  end
end
