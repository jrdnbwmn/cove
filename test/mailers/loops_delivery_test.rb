require "test_helper"

class LoopsDeliveryTest < ActiveSupport::TestCase
  setup do
    @transactional_id = "cmsdnzduk02k40jx72rv3uwe2"
    @data_variables = {"recipient_email" => "user@example.com"}
    @delivery = LoopsDelivery.new({})
  end

  def build_mail(to: ["user@example.com"], transactional_id: @transactional_id, data_variables: @data_variables)
    mail = Mail.new(to: to, from: "noreply@example.com", subject: "test", body: "")
    mail["X-Loops-Transactional-Id"] = transactional_id if transactional_id
    mail["X-Loops-Data-Variables"] = data_variables.is_a?(String) ? data_variables : data_variables.to_json unless data_variables.nil?
    mail
  end

  def deliver(mail)
    Rails.application.credentials.stub(:dig, "test-token") do
      @delivery.deliver!(mail)
    end
  end

  test "registers :loops as an Action Mailer delivery method" do
    assert_equal LoopsDelivery, ActionMailer::Base.delivery_methods[:loops]
  end

  test "issues exactly one authorized transactional request with the expected id and variables" do
    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(
        body: hash_including(
          "email" => "user@example.com",
          "transactionalId" => @transactional_id,
          "dataVariables" => @data_variables
        ),
        headers: {"Authorization" => /Bearer/}
      )
      .to_return(status: 200, body: {success: true}.to_json)

    deliver(build_mail)

    assert_requested stub, times: 1
  end

  test "sets the Idempotency-Key to LoopsClient's derived key" do
    client = LoopsClient.client
    expected_key = client.idempotency_key(@transactional_id, "user@example.com", @data_variables)

    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(headers: {"Idempotency-Key" => expected_key})
      .to_return(status: 200, body: {success: true}.to_json)

    deliver(build_mail)

    assert_requested stub, times: 1
  end

  test "issues one request per recipient" do
    stub_one = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("email" => "one@example.com"))
      .to_return(status: 200, body: {success: true}.to_json)
    stub_two = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("email" => "two@example.com"))
      .to_return(status: 200, body: {success: true}.to_json)

    deliver(build_mail(to: ["one@example.com", "two@example.com"]))

    assert_requested stub_one, times: 1
    assert_requested stub_two, times: 1
  end

  test "fails loudly before any request when the transactional id header is missing" do
    assert_raises(LoopsDelivery::MissingHeader) do
      deliver(build_mail(transactional_id: nil))
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
  end

  test "fails loudly before any request when the data variables header is missing" do
    assert_raises(LoopsDelivery::MissingHeader) do
      deliver(build_mail(data_variables: nil))
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
  end

  test "fails loudly before any request when the data variables header is malformed JSON" do
    assert_raises(LoopsDelivery::InvalidDataVariables) do
      deliver(build_mail(data_variables: "{not valid json"))
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
  end

  test "fails loudly before any request when the data variables header is not a JSON object" do
    assert_raises(LoopsDelivery::InvalidDataVariables) do
      deliver(build_mail(data_variables: [1, 2, 3].to_json))
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"

    assert_raises(LoopsDelivery::InvalidDataVariables) do
      deliver(build_mail(data_variables: "\"just a string\""))
    end
  end

  test "propagates LoopsClient::RateLimit" do
    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 429)

    assert_raises(LoopsClient::RateLimit) do
      deliver(build_mail)
    end
  end

  test "propagates LoopsClient::UnprocessableContent" do
    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 422)

    assert_raises(LoopsClient::UnprocessableContent) do
      deliver(build_mail)
    end
  end
end
