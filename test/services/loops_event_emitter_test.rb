require "test_helper"

class LoopsEventEmitterTest < ActiveSupport::TestCase
  class RecordingClient
    attr_reader :events

    def initialize
      @events = []
    end

    def send_event(**attributes)
      events << attributes
    end
  end

  test "non-production and disabled configurations return before constructing a client" do
    %w[development test staging].each do |environment|
      factory = -> { flunk "client must not be constructed" }
      emitter = build_emitter(environment:, client_factory: factory)

      assert_nil emitter.emit(users(:marketing_subscribed), "user_signed_up")
    end

    emitter = build_emitter(config: config(enabled: false), client_factory: -> { flunk "client must not be constructed" })
    assert_nil emitter.emit(users(:marketing_subscribed), "user_signed_up")
  end

  test "consent gate blocks a Loops-sourced opt-in and an unsubscribed user" do
    client = RecordingClient.new
    subscribed_via_loops = users(:marketing_subscribed)
    subscribed_via_loops.update!(marketing_opt_in_source: "loops")

    build_emitter(client:).emit(subscribed_via_loops, "user_signed_up")
    build_emitter(client:).emit(users(:marketing_unsubscribed), "user_signed_up")

    assert_empty client.events
  end

  test "consenting user emits the minimal event payload" do
    client = RecordingClient.new
    user = users(:marketing_subscribed)

    build_emitter(client:).emit(user, "user_signed_up")

    assert_equal [{event_name: "user_signed_up", user_id: user.id.to_s, event_properties: {signed_up_at: user.created_at.iso8601}, idempotency_key: Digest::SHA256.hexdigest("user_signed_up:#{user.id}")}], client.events
  end

  test "makes one exact Loops event request with no top-level contact fields beyond userId" do
    user = users(:marketing_subscribed)
    request = stub_request(:post, "https://app.loops.so/api/v1/events/send")
      .with(
        body: {userId: user.id.to_s, eventName: "user_signed_up", eventProperties: {signed_up_at: user.created_at.iso8601}}.to_json,
        headers: {"Idempotency-Key" => Digest::SHA256.hexdigest("user_signed_up:#{user.id}")}
      )
      .to_return(status: 200, body: {success: true}.to_json)

    emitter_with_http_client.emit(user, "user_signed_up")

    assert_requested request, times: 1
  end

  test "a 409 reply is absorbed and returns true" do
    user = users(:marketing_subscribed)
    stub_request(:post, "https://app.loops.so/api/v1/events/send").to_return(status: 409)

    assert_equal true, emitter_with_http_client.emit(user, "user_signed_up")
  end

  test "a 500 reply raises LoopsClient::InternalError" do
    user = users(:marketing_subscribed)
    stub_request(:post, "https://app.loops.so/api/v1/events/send").to_return(status: 500)

    assert_raises(LoopsClient::InternalError) { emitter_with_http_client.emit(user, "user_signed_up") }
  end

  test "an unknown event name raises without any HTTP request" do
    request = stub_request(:post, "https://app.loops.so/api/v1/events/send")

    assert_raises(ArgumentError) { build_emitter.emit(users(:marketing_subscribed), "user_deleted") }

    assert_not_requested request
  end

  private

  def build_emitter(environment: "production", config: self.config, client: nil, client_factory: nil)
    LoopsEventEmitter.new(
      config:,
      environment: ActiveSupport::StringInquirer.new(environment),
      client:,
      client_factory: client_factory || -> { RecordingClient.new }
    )
  end

  def config(enabled: true)
    ActiveSupport::OrderedOptions.new.tap do |result|
      result.contact_sync_enabled = enabled
    end
  end

  def emitter_with_http_client
    build_emitter(client: LoopsClient.new(token: "test-token"))
  end
end
