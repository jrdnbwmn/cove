require "test_helper"

class LoopsClientTest < ActiveSupport::TestCase
  setup do
    @client = LoopsClient.new(token: "test-token")
    @email = "recipient@example.com"
    @transactional_id = "clx_transactional_email"
    @data_variables = {name: "Jordan", invoice_number: "INV-123"}
  end

  test "sends a transactional email with the configured authorization and idempotency key" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(
        body: {
          email: @email,
          transactionalId: @transactional_id,
          addToAudience: false,
          dataVariables: @data_variables
        }.to_json,
        headers: {
          "Authorization" => "Bearer test-token",
          "Idempotency-Key" => @client.idempotency_key(@transactional_id, @email, @data_variables)
        }
      )
      .to_return(status: 200, body: {success: true}.to_json)

    assert @client.send_transactional(email: @email, transactional_id: @transactional_id, data_variables: @data_variables)
    assert_requested stub, times: 1
  end

  test "does not let data variables opt a recipient into the audience" do
    stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("addToAudience" => false, "dataVariables" => {"addToAudience" => true}))
      .to_return(status: 200)

    assert @client.send_transactional(
      email: @email,
      transactional_id: @transactional_id,
      data_variables: {addToAudience: true}
    )
  end

  test "uses a stable recipient-specific idempotency key" do
    reordered_variables = {invoice_number: "INV-123", name: "Jordan"}
    first_key = @client.idempotency_key(@transactional_id, @email, @data_variables)
    second_key = @client.idempotency_key(@transactional_id, @email, reordered_variables)
    other_recipient_key = @client.idempotency_key(@transactional_id, "other@example.com", @data_variables)

    assert_equal first_key, second_key
    assert_not_equal first_key, other_recipient_key
    assert_operator first_key.length, :<=, 100
  end

  test "treats an idempotency conflict as a successful duplicate send" do
    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 409)

    assert @client.send_transactional(email: @email, transactional_id: @transactional_id)
  end

  test "raises Loops-specific errors for bad requests and oversized payloads" do
    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 400)
    assert_raises LoopsClient::BadRequest do
      @client.send_transactional(email: @email, transactional_id: @transactional_id)
    end

    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 413)
    assert_raises LoopsClient::PayloadTooLarge do
      @client.send_transactional(email: @email, transactional_id: @transactional_id)
    end
  end

  test "retains inherited errors for unprocessable content rate limits and server errors" do
    {422 => LoopsClient::UnprocessableContent, 429 => LoopsClient::RateLimit, 500 => LoopsClient::InternalError}.each do |status, error|
      stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: status)

      assert_raises error do
        @client.send_transactional(email: @email, transactional_id: @transactional_id)
      end
    end
  end

  test "builds a credential-backed client with the configured timeouts" do
    Rails.application.credentials.stub(:dig, "credential-token") do
      client = LoopsClient.client

      assert_equal "credential-token", client.token
      assert_equal 2, client.open_timeout
      assert_equal 5, client.read_timeout
    end
  end

  test "direct initialization and the credential-backed factory work without a throttler" do
    stub_request(:post, "https://app.loops.so/api/v1/contacts/create").to_return(status: 200, body: {success: true, id: "abc"}.to_json, headers: {"Content-Type" => "application/json"})

    client = LoopsClient.new(token: "test-token")
    assert_equal({"success" => true, "id" => "abc"}, client.create_contact(email: @email).to_h.stringify_keys)

    Rails.application.credentials.stub(:dig, "credential-token") do
      factory_client = LoopsClient.client
      assert_equal "credential-token", factory_client.token
    end
  end

  test "direct initialization and the factory retain and invoke a supplied throttler" do
    calls = []

    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :direct })
    stub_request(:post, "https://app.loops.so/api/v1/contacts/create").to_return(status: 200, body: {success: true}.to_json)
    client.create_contact(email: @email)
    assert_equal [:direct], calls

    Rails.application.credentials.stub(:dig, "credential-token") do
      factory_client = LoopsClient.client(throttler: -> { calls << :factory })
      factory_client.create_contact(email: @email)
    end
    assert_equal [:direct, :factory], calls
  end

  test "creates a contact with a single authorized request" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(
        body: {email: @email}.to_json,
        headers: {"Authorization" => "Bearer test-token"}
      )
      .to_return(status: 200, body: {success: true, id: "contact_123"}.to_json, headers: {"Content-Type" => "application/json"})

    result = @client.create_contact(email: @email)

    assert_equal({"success" => true, "id" => "contact_123"}, result.to_h.stringify_keys)
    assert_requested stub, times: 1
  end

  test "updates a contact with a single authorized request" do
    stub = stub_request(:put, "https://app.loops.so/api/v1/contacts/update")
      .with(
        body: {userId: "user_1"}.to_json,
        headers: {"Authorization" => "Bearer test-token"}
      )
      .to_return(status: 200, body: {success: true, id: "contact_123"}.to_json, headers: {"Content-Type" => "application/json"})

    result = @client.update_contact(user_id: "user_1")

    assert_equal({"success" => true, "id" => "contact_123"}, result.to_h.stringify_keys)
    assert_requested stub, times: 1
  end

  test "omits an unspecified subscribed value while preserving explicit true or false" do
    omitted_stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(body: {email: @email}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)
    @client.create_contact(email: @email)
    assert_requested omitted_stub, times: 1

    false_stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(body: {email: @email, subscribed: false}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)
    @client.create_contact(email: @email, subscribed: false)
    assert_requested false_stub, times: 1

    true_stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(body: {email: @email, subscribed: true}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)
    @client.create_contact(email: @email, subscribed: true)
    assert_requested true_stub, times: 1
  end

  test "serializes mailing list ids as string keys and preserves both membership values" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(body: {email: @email, mailingLists: {"list_1" => true, "list_2" => false}}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)

    @client.create_contact(email: @email, mailing_lists: {:list_1 => true, "list_2" => false})

    assert_requested stub, times: 1
  end

  test "raises before throttling or HTTP when mailing list membership is not boolean" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises ArgumentError do
      client.create_contact(email: @email, mailing_lists: {list_1: "yes"})
    end
    assert_empty calls
    assert_not_requested :post, "https://app.loops.so/api/v1/contacts/create"
  end

  test "preserves custom nil property values and non-reserved key spelling" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(body: {:email => @email, :favoriteColor => nil, "plan" => "pro"}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)

    @client.create_contact(email: @email, contact_properties: {:favoriteColor => nil, "plan" => "pro"})

    assert_requested stub, times: 1
  end

  test "does not let conflicting custom properties override client-owned contact fields" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/create")
      .with(body: {email: @email, userId: "user_1", subscribed: true, mailingLists: {"list_1" => true}}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)

    @client.create_contact(
      email: @email,
      user_id: "user_1",
      subscribed: true,
      mailing_lists: {list_1: true},
      contact_properties: {
        "email" => "other@example.com",
        :userId => "user_2",
        :subscribed => false,
        :mailingLists => {"list_2" => true}
      }
    )

    assert_requested stub, times: 1
  end

  test "raises before HTTP when create is missing a blank email" do
    assert_raises ArgumentError do
      @client.create_contact(email: "")
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/contacts/create"
  end

  test "raises before HTTP when update is missing both identifiers" do
    assert_raises ArgumentError do
      @client.update_contact
    end
    assert_not_requested :put, "https://app.loops.so/api/v1/contacts/update"
  end

  test "raises Conflict when contact creation returns 409" do
    stub_request(:post, "https://app.loops.so/api/v1/contacts/create").to_return(status: 409)

    assert_raises LoopsClient::Conflict do
      @client.create_contact(email: @email)
    end
  end

  test "finds a contact by email with a single authorized request" do
    stub = stub_request(:get, "https://app.loops.so/api/v1/contacts/find")
      .with(query: {email: @email}, headers: {"Authorization" => "Bearer test-token"})
      .to_return(status: 200, body: [{id: "contact_123", email: @email}].to_json, headers: {"Content-Type" => "application/json"})

    result = @client.find_contact(email: @email)

    assert_equal [{"id" => "contact_123", "email" => @email}], result.map { |c| c.to_h.stringify_keys }
    assert_requested stub, times: 1
  end

  test "finds a contact by user_id mapped to userId query param" do
    stub = stub_request(:get, "https://app.loops.so/api/v1/contacts/find")
      .with(query: {userId: "user_1"})
      .to_return(status: 200, body: [].to_json, headers: {"Content-Type" => "application/json"})

    result = @client.find_contact(user_id: "user_1")

    assert_equal [], result
    assert_requested stub, times: 1
  end

  test "returns an empty array when find_contact finds no contact" do
    stub_request(:get, "https://app.loops.so/api/v1/contacts/find")
      .with(query: {email: @email})
      .to_return(status: 200, body: [].to_json, headers: {"Content-Type" => "application/json"})

    assert_equal [], @client.find_contact(email: @email)
  end

  test "find_contact raises before HTTP for missing, blank, or ambiguous identifiers" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.find_contact }
    assert_raises(ArgumentError) { client.find_contact(email: "", user_id: "") }
    assert_raises(ArgumentError) { client.find_contact(email: @email, user_id: "user_1") }

    assert_empty calls
    assert_not_requested :get, "https://app.loops.so/api/v1/contacts/find"
  end

  test "deletes a contact with exactly one identifier in the JSON body" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/delete")
      .with(body: {email: @email}.to_json, headers: {"Authorization" => "Bearer test-token"})
      .to_return(status: 200, body: {success: true, message: "Contact deleted."}.to_json, headers: {"Content-Type" => "application/json"})

    result = @client.delete_contact(email: @email)

    assert_equal({"success" => true, "message" => "Contact deleted."}, result.to_h.stringify_keys)
    assert_requested stub, times: 1
  end

  test "deletes a contact by user_id mapped to userId in the body" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/contacts/delete")
      .with(body: {userId: "user_1"}.to_json)
      .to_return(status: 200, body: {success: true, message: "Contact deleted."}.to_json, headers: {"Content-Type" => "application/json"})

    @client.delete_contact(user_id: "user_1")

    assert_requested stub, times: 1
  end

  test "delete_contact raises before HTTP for missing, blank, or ambiguous identifiers" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.delete_contact }
    assert_raises(ArgumentError) { client.delete_contact(email: "", user_id: "") }
    assert_raises(ArgumentError) { client.delete_contact(email: @email, user_id: "user_1") }

    assert_empty calls
    assert_not_requested :post, "https://app.loops.so/api/v1/contacts/delete"
  end

  test "reads suppression status with contact isSuppressed and removal quota" do
    stub = stub_request(:get, "https://app.loops.so/api/v1/contacts/suppression")
      .with(query: {email: @email}, headers: {"Authorization" => "Bearer test-token"})
      .to_return(
        status: 200,
        body: {
          contact: {id: "contact_123", email: @email},
          isSuppressed: true,
          removalQuota: {limit: 10, remaining: 3}
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.suppression_status(email: @email)

    assert_equal "contact_123", result.contact.id
    assert_equal true, result.isSuppressed
    assert_equal 10, result.removalQuota.limit
    assert_equal 3, result.removalQuota.remaining
    assert_requested stub, times: 1
  end

  test "reads suppression status by user_id mapped to userId query param" do
    stub = stub_request(:get, "https://app.loops.so/api/v1/contacts/suppression")
      .with(query: {userId: "user_1"})
      .to_return(status: 200, body: {contact: nil, isSuppressed: false, removalQuota: {limit: 10, remaining: 10}}.to_json, headers: {"Content-Type" => "application/json"})

    @client.suppression_status(user_id: "user_1")

    assert_requested stub, times: 1
  end

  test "suppression_status raises before HTTP for missing, blank, or ambiguous identifiers" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.suppression_status }
    assert_raises(ArgumentError) { client.suppression_status(email: "", user_id: "") }
    assert_raises(ArgumentError) { client.suppression_status(email: @email, user_id: "user_1") }

    assert_empty calls
    assert_not_requested :get, "https://app.loops.so/api/v1/contacts/suppression"
  end

  test "removes suppression and returns the updated removal quota" do
    stub = stub_request(:delete, "https://app.loops.so/api/v1/contacts/suppression")
      .with(query: {email: @email}, headers: {"Authorization" => "Bearer test-token"})
      .to_return(
        status: 200,
        body: {success: true, message: "Suppression removed.", removalQuota: {limit: 10, remaining: 2}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.remove_suppression(email: @email)

    assert_equal true, result.success
    assert_equal 2, result.removalQuota.remaining
    assert_requested stub, times: 1
  end

  test "removes suppression by user_id mapped to userId query param" do
    stub = stub_request(:delete, "https://app.loops.so/api/v1/contacts/suppression")
      .with(query: {userId: "user_1"})
      .to_return(status: 200, body: {success: true, message: "ok", removalQuota: {limit: 10, remaining: 9}}.to_json, headers: {"Content-Type" => "application/json"})

    @client.remove_suppression(user_id: "user_1")

    assert_requested stub, times: 1
  end

  test "remove_suppression raises before HTTP for missing, blank, or ambiguous identifiers" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.remove_suppression }
    assert_raises(ArgumentError) { client.remove_suppression(email: "", user_id: "") }
    assert_raises(ArgumentError) { client.remove_suppression(email: @email, user_id: "user_1") }

    assert_empty calls
    assert_not_requested :delete, "https://app.loops.so/api/v1/contacts/suppression"
  end

  test "lists mailing lists with a single authorized request" do
    stub = stub_request(:get, "https://app.loops.so/api/v1/lists")
      .with(headers: {"Authorization" => "Bearer test-token"})
      .to_return(status: 200, body: [{id: "list_1", name: "Newsletter", description: "Weekly digest", isPublic: true}].to_json, headers: {"Content-Type" => "application/json"})

    result = @client.list_mailing_lists

    assert_equal [{"id" => "list_1", "name" => "Newsletter", "description" => "Weekly digest", "isPublic" => true}], result.map { |l| l.to_h.stringify_keys }
    assert_requested stub, times: 1
  end

  test "sends an event with a single authorized request" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/events/send")
      .with(
        body: {
          email: @email,
          userId: "user_1",
          eventName: "signup",
          eventProperties: {plan: "pro"},
          mailingLists: {"list_1" => true}
        }.to_json,
        headers: {"Authorization" => "Bearer test-token"}
      )
      .to_return(status: 200, body: {success: true}.to_json)

    assert_equal true, @client.send_event(
      event_name: "signup",
      email: @email,
      user_id: "user_1",
      event_properties: {plan: "pro"},
      mailing_lists: {list_1: true}
    )
    assert_requested stub, times: 1
  end

  test "merges top-level contact properties into a sent event, preserving nil values" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/events/send")
      .with(body: {email: @email, eventName: "signup", eventProperties: {}, favoriteColor: nil, plan: "pro"}.to_json)
      .to_return(status: 200, body: {success: true}.to_json)

    @client.send_event(event_name: "signup", email: @email, contact_properties: {favoriteColor: nil, plan: "pro"})

    assert_requested stub, times: 1
  end

  test "does not let conflicting custom properties override client-owned event fields" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/events/send")
      .with(body: {
        email: @email,
        userId: "user_1",
        eventName: "signup",
        eventProperties: {plan: "pro"},
        mailingLists: {"list_1" => true}
      }.to_json)
      .to_return(status: 200, body: {success: true}.to_json)

    @client.send_event(
      event_name: "signup",
      email: @email,
      user_id: "user_1",
      event_properties: {plan: "pro"},
      mailing_lists: {list_1: true},
      contact_properties: {
        "email" => "other@example.com",
        :userId => "user_2",
        :eventName => "other_event",
        :eventProperties => {other: true},
        :mailingLists => {"list_2" => true}
      }
    )

    assert_requested stub, times: 1
  end

  test "adds an Idempotency-Key header only when a key is supplied" do
    with_key = stub_request(:post, "https://app.loops.so/api/v1/events/send")
      .with(headers: {"Idempotency-Key" => "key-123"})
      .to_return(status: 200, body: {success: true}.to_json)
    @client.send_event(event_name: "signup", email: @email, idempotency_key: "key-123")
    assert_requested with_key, times: 1

    without_key = stub_request(:post, "https://app.loops.so/api/v1/events/send")
      .with { |request| !request.headers.key?("Idempotency-Key") }
      .to_return(status: 200, body: {success: true}.to_json)
    @client.send_event(event_name: "signup", email: @email)
    assert_requested without_key, times: 1
  end

  test "send_event raises before throttling or HTTP for a missing or blank event name" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.send_event(event_name: "", email: @email) }
    assert_raises(ArgumentError) { client.send_event(event_name: nil, email: @email) }

    assert_empty calls
    assert_not_requested :post, "https://app.loops.so/api/v1/events/send"
  end

  test "send_event raises before throttling or HTTP when both identifiers are missing" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.send_event(event_name: "signup") }

    assert_empty calls
    assert_not_requested :post, "https://app.loops.so/api/v1/events/send"
  end

  test "send_event raises before throttling or HTTP when mailing list membership is not boolean" do
    calls = []
    client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })

    assert_raises(ArgumentError) { client.send_event(event_name: "signup", email: @email, mailing_lists: {list_1: "yes"}) }

    assert_empty calls
    assert_not_requested :post, "https://app.loops.so/api/v1/events/send"
  end

  test "returns true for a successful event send" do
    stub_request(:post, "https://app.loops.so/api/v1/events/send").to_return(status: 200, body: {success: true}.to_json)

    assert_equal true, @client.send_event(event_name: "signup", email: @email)
  end

  test "returns true for an event conflict caused by a reused idempotency key" do
    stub_request(:post, "https://app.loops.so/api/v1/events/send").to_return(status: 409)

    assert_equal true, @client.send_event(event_name: "signup", email: @email, idempotency_key: "key-123")
  end

  test "propagates a Conflict raised by the event throttler without making an HTTP request" do
    client = LoopsClient.new(token: "test-token", throttler: -> { raise LoopsClient::Conflict, "throttle conflict" })
    stub = stub_request(:post, "https://app.loops.so/api/v1/events/send")

    error = assert_raises(LoopsClient::Conflict) do
      client.send_event(event_name: "signup", email: @email)
    end

    assert_equal "throttle conflict", error.message
    assert_not_requested stub
  end

  test "the default throttler is a no-op" do
    assert_equal LoopsClient::NO_OP_THROTTLER, @client.throttler
    assert_nil @client.throttler.call
  end

  test "every new marketing method retains inherited 422 and 429 typed errors" do
    marketing_method_examples.each do |example|
      build_stub(example).to_return(status: 422)
      assert_raises(LoopsClient::UnprocessableContent, "expected 422 handling for #{example[:name]}") do
        example[:call].call(@client)
      end

      build_stub(example).to_return(status: 429)
      assert_raises(LoopsClient::RateLimit, "expected 429 handling for #{example[:name]}") do
        example[:call].call(@client)
      end
    end
  end

  test "the throttler runs exactly once immediately before every new marketing HTTP request" do
    marketing_method_examples.each do |example|
      calls = []
      client = LoopsClient.new(token: "test-token", throttler: -> { calls << :throttled })
      stub = build_stub(example).to_return(status: 200, body: {success: true}.to_json, headers: {"Content-Type" => "application/json"})

      example[:call].call(client)

      assert_equal [:throttled], calls, "expected exactly one throttler call for #{example[:name]}"
      assert_requested stub, times: 1
    end
  end

  test "a raising throttler propagates and prevents HTTP for every new marketing method" do
    marketing_method_examples.each do |example|
      client = LoopsClient.new(token: "test-token", throttler: -> { raise "throttle boom" })
      stub = build_stub(example).to_return(status: 200, body: {success: true}.to_json)

      error = assert_raises(RuntimeError, "expected the throttler's exception for #{example[:name]}") do
        example[:call].call(client)
      end
      assert_equal "throttle boom", error.message
      assert_not_requested stub
    end
  end

  private

  def build_stub(example)
    stub = stub_request(example[:verb], example[:url])
    example[:query] ? stub.with(query: example[:query]) : stub
  end

  def marketing_method_examples
    [
      {name: "create_contact", verb: :post, url: "https://app.loops.so/api/v1/contacts/create", call: ->(client) { client.create_contact(email: @email) }},
      {name: "update_contact", verb: :put, url: "https://app.loops.so/api/v1/contacts/update", call: ->(client) { client.update_contact(email: @email) }},
      {name: "find_contact", verb: :get, url: "https://app.loops.so/api/v1/contacts/find", query: {email: @email}, call: ->(client) { client.find_contact(email: @email) }},
      {name: "delete_contact", verb: :post, url: "https://app.loops.so/api/v1/contacts/delete", call: ->(client) { client.delete_contact(email: @email) }},
      {name: "suppression_status", verb: :get, url: "https://app.loops.so/api/v1/contacts/suppression", query: {email: @email}, call: ->(client) { client.suppression_status(email: @email) }},
      {name: "remove_suppression", verb: :delete, url: "https://app.loops.so/api/v1/contacts/suppression", query: {email: @email}, call: ->(client) { client.remove_suppression(email: @email) }},
      {name: "list_mailing_lists", verb: :get, url: "https://app.loops.so/api/v1/lists", call: ->(client) { client.list_mailing_lists }},
      {name: "send_event", verb: :post, url: "https://app.loops.so/api/v1/events/send", call: ->(client) { client.send_event(event_name: "signup", email: @email) }}
    ]
  end
end
