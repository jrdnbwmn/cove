require "test_helper"

class LoopsContactSynchronizerTest < ActiveSupport::TestCase
  LIST_ID = "cmsdo8ncl02wc0j0j4rxwhy4l"

  class RecordingClient
    attr_reader :updates, :deletions

    def initialize
      @updates = []
      @deletions = []
    end

    def update_contact(**attributes)
      updates << attributes
    end

    def delete_contact(**attributes)
      deletions << attributes
    end
  end

  test "checked-in configuration has the Cove updates list and explicit environment flags" do
    config = Rails.application.config_for(:loops)

    assert_equal LIST_ID, config.contact_sync_mailing_list_id
    assert_equal true, Rails.application.config_for(:loops, env: "production").contact_sync_enabled
    %w[development test staging].each do |environment|
      assert_equal false, Rails.application.config_for(:loops, env: environment).contact_sync_enabled
    end
  end

  test "non-production and disabled configurations return before constructing a client" do
    %w[development test staging].each do |environment|
      factory = -> { flunk "client must not be constructed" }
      synchronizer = build_synchronizer(environment:, client_factory: factory)

      assert_nil synchronizer.sync(users(:marketing_subscribed), intent: :opt_in)
    end

    synchronizer = build_synchronizer(config: config(enabled: false), client_factory: -> { flunk "client must not be constructed" })
    assert_nil synchronizer.sync(users(:marketing_subscribed), intent: :opt_in)
  end

  test "missing list configuration fails visibly for live writes and backfill readiness" do
    synchronizer = build_synchronizer(config: config(list_id: nil))

    [:opt_in, :opt_out].each do |intent|
      assert_raises LoopsContactSynchronizer::ConfigurationError do
        synchronizer.sync(users(:marketing_subscribed), intent:)
      end
    end
    assert_raises(LoopsContactSynchronizer::ConfigurationError) { synchronizer.ensure_backfill_ready! }
  end

  test "current opt-in sends the minimal subscribed list payload" do
    client = RecordingClient.new
    user = users(:marketing_subscribed)

    build_synchronizer(client:).sync(user, intent: :opt_in)

    assert_equal [{email: user.email, user_id: user.id.to_s, subscribed: true, mailing_lists: {LIST_ID => true}}], client.updates
  end

  test "current opt-in makes one exact Loops update request" do
    user = users(:marketing_subscribed)
    request = stub_request(:put, "https://app.loops.so/api/v1/contacts/update")
      .with(
        body: {
          email: user.email,
          userId: user.id.to_s,
          subscribed: true,
          mailingLists: {LIST_ID => true}
        }.to_json,
        headers: {"Authorization" => "Bearer test-token"}
      )
      .to_return(status: 200, body: {success: true}.to_json)

    synchronizer_with_http_client.sync(user, intent: :opt_in)

    assert_requested request, times: 1
  end

  test "current app opt-out sends the minimal unsubscribed list payload" do
    client = RecordingClient.new
    user = users(:marketing_unsubscribed)

    build_synchronizer(client:).sync(user, intent: :opt_out)

    assert_equal [{user_id: user.id.to_s, subscribed: false, mailing_lists: {LIST_ID => false}}], client.updates
  end

  test "current app opt-out makes one exact Loops update request" do
    user = users(:marketing_unsubscribed)
    request = stub_request(:put, "https://app.loops.so/api/v1/contacts/update")
      .with(body: {userId: user.id.to_s, subscribed: false, mailingLists: {LIST_ID => false}}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)

    synchronizer_with_http_client.sync(user, intent: :opt_out)

    assert_requested request, times: 1
  end

  test "email change sends the current email and identifier without consent fields" do
    client = RecordingClient.new
    user = users(:marketing_subscribed)

    build_synchronizer(client:).sync(user, intent: :email_change)

    assert_equal [{email: user.email, user_id: user.id.to_s}], client.updates
  end

  test "stale and protected consent intents do not write" do
    client = RecordingClient.new
    synchronizer = build_synchronizer(client:)
    subscribed = users(:marketing_subscribed)
    unsubscribed = users(:marketing_unsubscribed)

    synchronizer.sync(unsubscribed, intent: :opt_in)
    synchronizer.sync(subscribed, intent: :opt_out)
    unsubscribed.update!(marketing_opt_out_reason: "hard_bounce")
    synchronizer.sync(unsubscribed, intent: :opt_out)
    subscribed.update!(marketing_opt_in_source: "loops")
    synchronizer.sync(subscribed, intent: :opt_in)

    assert_empty client.updates
  end

  test "deletion uses a string user ID and treats a missing Loops contact as complete" do
    client = RecordingClient.new
    build_synchronizer(client:).delete(users(:one).id)

    assert_equal [{user_id: users(:one).id.to_s}], client.deletions

    missing_client = Object.new
    missing_client.define_singleton_method(:delete_contact) { |**| raise LoopsClient::NotFound }
    assert_nil build_synchronizer(client: missing_client).delete(users(:one).id)
  end

  test "deletion posts one plain string user ID and accepts a missing contact" do
    user = users(:one)
    request = stub_request(:post, "https://app.loops.so/api/v1/contacts/delete")
      .with(body: {userId: user.id.to_s}.to_json)
      .to_return(status: 404)

    assert_nil synchronizer_with_http_client.delete(user.id)
    assert_requested request, times: 1
  end

  private

  def build_synchronizer(environment: "production", config: self.config, client: nil, client_factory: nil)
    LoopsContactSynchronizer.new(
      config:,
      environment: ActiveSupport::StringInquirer.new(environment),
      client:,
      client_factory: client_factory || -> { RecordingClient.new }
    )
  end

  def config(enabled: true, list_id: LIST_ID)
    ActiveSupport::OrderedOptions.new.tap do |result|
      result.contact_sync_enabled = enabled
      result.contact_sync_mailing_list_id = list_id
    end
  end

  def synchronizer_with_http_client
    build_synchronizer(client: LoopsClient.new(token: "test-token"))
  end
end
