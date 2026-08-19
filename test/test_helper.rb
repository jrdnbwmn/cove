ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"

# Uncomment to view full stack trace in tests
# Rails.backtrace_cleaner.remove_silencers!

if defined?(Sidekiq)
  require "sidekiq/testing"
  Sidekiq.logger.level = Logger::WARN
end

if defined?(SolidQueue)
  SolidQueue.logger.level = Logger::WARN
end

# Generate a random password so Chrome doesn't warn about passwords in data breaches
UNIQUE_PASSWORD = Devise.friendly_token

LOOPS_WEBHOOK_TEST_SECRET = "whsec_#{Base64.strict_encode64("test-signing-key")}"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def json_response
      JSON.decode(response.body)
    end

    def sign_loops_webhook(webhook_id, timestamp, payload, secret: LOOPS_WEBHOOK_TEST_SECRET)
      key = Base64.decode64(secret.split("_")[1])
      digest = OpenSSL::HMAC.digest("SHA256", key, "#{webhook_id}.#{timestamp}.#{payload}")
      Base64.strict_encode64(digest)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers

    def switch_account(account)
      patch "/accounts/#{account.id}/switch"
    end

    def post_loops_webhook(webhook_id:, body:, signature: nil, timestamp: "1700000000", secret: LOOPS_WEBHOOK_TEST_SECRET)
      signature ||= "v1,#{sign_loops_webhook(webhook_id, timestamp, body, secret: secret)}"

      post "/webhooks/loops",
        params: body,
        headers: {
          "Webhook-Id" => webhook_id,
          "Webhook-Timestamp" => timestamp,
          "Webhook-Signature" => signature,
          "Content-Type" => "application/json"
        }
    end
  end
end

WebMock.disable_net_connect!({
  allow_localhost: true,
  allow: [
    "chromedriver.storage.googleapis.com",
    "rails-app",
    "selenium"
  ]
})
