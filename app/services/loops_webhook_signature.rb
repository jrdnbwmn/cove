# AIDEV-NOTE: the secret is prefix-stripped (before the first "_") *then*
# base64-decoded — COV-48's brief said only "base64-decoded", and getting
# this wrong makes every event fail signature verification silently.
class LoopsWebhookSignature
  def self.secret
    Rails.application.credentials.dig(:loops, :webhook_secret)
  end

  def initialize(secret:)
    @secret = secret
  end

  def valid?(webhook_id:, timestamp:, payload:, signature_header:)
    return false if secret.blank?
    return false unless secret.include?("_")
    return false if webhook_id.blank? || timestamp.blank?
    return false if signature_header.blank?

    expected = expected_signature(webhook_id, timestamp, payload)
    return false if expected.nil?

    signature_header.split(" ").any? do |entry|
      _version, signature = entry.split(",", 2)
      signature.present? && ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end
  end

  private

  attr_reader :secret

  def expected_signature(webhook_id, timestamp, payload)
    key = Base64.decode64(secret.split("_")[1])
    digest = OpenSSL::HMAC.digest("SHA256", key, "#{webhook_id}.#{timestamp}.#{payload}")
    Base64.strict_encode64(digest)
  rescue
    nil
  end
end
