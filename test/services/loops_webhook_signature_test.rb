require "test_helper"

class LoopsWebhookSignatureTest < ActiveSupport::TestCase
  SECRET = "whsec_#{Base64.strict_encode64("test-signing-key")}"

  def sign(secret, webhook_id, timestamp, payload)
    key = Base64.decode64(secret.split("_")[1])
    digest = OpenSSL::HMAC.digest("SHA256", key, "#{webhook_id}.#{timestamp}.#{payload}")
    Base64.strict_encode64(digest)
  end

  test "validates a correctly computed signature" do
    webhook_id = "wh_1"
    timestamp = "1700000000"
    payload = '{"eventName":"contact.unsubscribed"}'
    signature = sign(SECRET, webhook_id, timestamp, payload)

    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert verifier.valid?(webhook_id: webhook_id, timestamp: timestamp, payload: payload, signature_header: "v1,#{signature}")
  end

  test "validates when the matching entry is among several header entries" do
    webhook_id = "wh_1"
    timestamp = "1700000000"
    payload = "{}"
    signature = sign(SECRET, webhook_id, timestamp, payload)

    verifier = LoopsWebhookSignature.new(secret: SECRET)
    header = "v1,wrongsignature v1,#{signature}"

    assert verifier.valid?(webhook_id: webhook_id, timestamp: timestamp, payload: payload, signature_header: header)
  end

  test "rejects a wrong signature" do
    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: "wh_1", timestamp: "1700000000", payload: "{}", signature_header: "v1,bm90YXNpZ25hdHVyZQ==")
  end

  test "rejects a tampered body" do
    webhook_id = "wh_1"
    timestamp = "1700000000"
    signature = sign(SECRET, webhook_id, timestamp, "{}")

    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: webhook_id, timestamp: timestamp, payload: '{"tampered":true}', signature_header: "v1,#{signature}")
  end

  test "rejects a tampered webhook id" do
    timestamp = "1700000000"
    payload = "{}"
    signature = sign(SECRET, "wh_1", timestamp, payload)

    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: "wh_2", timestamp: timestamp, payload: payload, signature_header: "v1,#{signature}")
  end

  test "rejects a tampered timestamp" do
    webhook_id = "wh_1"
    payload = "{}"
    signature = sign(SECRET, webhook_id, "1700000000", payload)

    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: webhook_id, timestamp: "1700000001", payload: payload, signature_header: "v1,#{signature}")
  end

  test "rejects a missing header" do
    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: "wh_1", timestamp: "1700000000", payload: "{}", signature_header: nil)
  end

  test "rejects a malformed header" do
    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: "wh_1", timestamp: "1700000000", payload: "{}", signature_header: "not-a-valid-header")
  end

  test "rejects a nil secret" do
    verifier = LoopsWebhookSignature.new(secret: nil)

    assert_not verifier.valid?(webhook_id: "wh_1", timestamp: "1700000000", payload: "{}", signature_header: "v1,anything")
  end

  test "rejects a secret without an underscore" do
    verifier = LoopsWebhookSignature.new(secret: "nounderscorehere")

    assert_not verifier.valid?(webhook_id: "wh_1", timestamp: "1700000000", payload: "{}", signature_header: "v1,anything")
  end

  test "rejects a blank webhook_id" do
    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: "", timestamp: "1700000000", payload: "{}", signature_header: "v1,anything")
  end

  test "rejects a blank timestamp" do
    verifier = LoopsWebhookSignature.new(secret: SECRET)

    assert_not verifier.valid?(webhook_id: "wh_1", timestamp: "", payload: "{}", signature_header: "v1,anything")
  end

  test ".secret reads from credentials" do
    Rails.application.credentials.stub(:dig, "whsec_stub") do
      assert_equal "whsec_stub", LoopsWebhookSignature.secret
    end
  end
end
