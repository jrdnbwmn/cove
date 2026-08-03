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
end
