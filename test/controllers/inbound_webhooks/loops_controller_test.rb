require "test_helper"

class InboundWebhooks::LoopsControllerTest < ActionDispatch::IntegrationTest
  SECRET = "whsec_#{Base64.strict_encode64("test-signing-key")}"

  def sign(webhook_id, timestamp, payload)
    key = Base64.decode64(SECRET.split("_")[1])
    digest = OpenSSL::HMAC.digest("SHA256", key, "#{webhook_id}.#{timestamp}.#{payload}")
    "v1,#{Base64.strict_encode64(digest)}"
  end

  def post_webhook(webhook_id:, body:, signature: nil, timestamp: "1700000000")
    signature ||= sign(webhook_id, timestamp, body)

    post "/webhooks/loops",
      params: body,
      headers: {
        "Webhook-Id" => webhook_id,
        "Webhook-Timestamp" => timestamp,
        "Webhook-Signature" => signature,
        "Content-Type" => "application/json"
      }
  end

  test "a validly signed request returns 200, creates one row, and enqueues one job" do
    LoopsWebhookSignature.stub(:secret, SECRET) do
      body = {"eventName" => "contact.unsubscribed", "eventTime" => 1700000000, "contactIdentity" => {"userId" => users(:marketing_subscribed).id.to_s}}.to_json

      assert_difference "LoopsWebhookEvent.count", 1 do
        assert_enqueued_jobs 1, only: LoopsWebhookEventJob do
          post_webhook(webhook_id: "wh_new", body: body)
        end
      end

      assert_response :ok
    end
  end

  test "missing signature returns 401 and creates nothing" do
    LoopsWebhookSignature.stub(:secret, SECRET) do
      body = {"eventName" => "contact.unsubscribed"}.to_json

      assert_no_difference "LoopsWebhookEvent.count" do
        post "/webhooks/loops", params: body, headers: {"Webhook-Id" => "wh_missing", "Webhook-Timestamp" => "1700000000", "Content-Type" => "application/json"}
      end

      assert_response :unauthorized
    end
  end

  test "malformed signature returns 401 and creates nothing" do
    LoopsWebhookSignature.stub(:secret, SECRET) do
      body = {"eventName" => "contact.unsubscribed"}.to_json

      assert_no_difference "LoopsWebhookEvent.count" do
        post_webhook(webhook_id: "wh_malformed", body: body, signature: "not-a-valid-header")
      end

      assert_response :unauthorized
    end
  end

  test "wrong signature returns 401 and creates nothing" do
    LoopsWebhookSignature.stub(:secret, SECRET) do
      body = {"eventName" => "contact.unsubscribed"}.to_json

      assert_no_difference "LoopsWebhookEvent.count" do
        post_webhook(webhook_id: "wh_wrong", body: body, signature: "v1,bm90YXNpZ25hdHVyZQ==")
      end

      assert_response :unauthorized
    end
  end

  test "malformed JSON with a valid signature returns 400" do
    LoopsWebhookSignature.stub(:secret, SECRET) do
      body = "not json"

      assert_no_difference "LoopsWebhookEvent.count" do
        post_webhook(webhook_id: "wh_badjson", body: body)
      end

      assert_response :bad_request
    end
  end

  test "a redelivered Webhook-Id returns 200, creates no second row, and enqueues nothing" do
    LoopsWebhookSignature.stub(:secret, SECRET) do
      body = {"eventName" => "contact.unsubscribed"}.to_json
      post_webhook(webhook_id: "wh_dupe", body: body)
      assert_response :ok

      assert_no_difference "LoopsWebhookEvent.count" do
        assert_no_enqueued_jobs only: LoopsWebhookEventJob do
          post_webhook(webhook_id: "wh_dupe", body: body)
        end
      end

      assert_response :ok
    end
  end

  test "with the secret unset every request is 401" do
    LoopsWebhookSignature.stub(:secret, nil) do
      body = {"eventName" => "contact.unsubscribed"}.to_json

      assert_no_difference "LoopsWebhookEvent.count" do
        post_webhook(webhook_id: "wh_nosecret", body: body)
      end

      assert_response :unauthorized
    end
  end
end
