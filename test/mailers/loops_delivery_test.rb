require "test_helper"

class LoopsDeliveryTest < ActiveSupport::TestCase
  setup do
    @transactional_id = "cmsdnzduk02k40jx72rv3uwe2"
    @data_variables = {"recipient_email" => "user@example.com"}
    @delivery = LoopsDelivery.new({})
  end

  def build_mail(to: ["user@example.com"], transactional_id: @transactional_id, data_variables: @data_variables, idempotency_seed: nil, attachments: [])
    mail = Mail.new(to: to, from: "noreply@example.com", subject: "test", body: "")
    mail["X-Loops-Transactional-Id"] = transactional_id if transactional_id
    mail["X-Loops-Data-Variables"] = data_variables.is_a?(String) ? data_variables : data_variables.to_json unless data_variables.nil?
    mail["X-Loops-Idempotency-Seed"] = idempotency_seed if idempotency_seed
    attachments.each do |attachment|
      mail.attachments[attachment.fetch(:filename)] = {
        mime_type: attachment.fetch(:content_type),
        content: attachment.fetch(:content)
      }
    end
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

  test "uses seeded recipient-specific keys for each unique normalized recipient" do
    seed = "charge:ch_123"
    transactional_id = "cmsdrk6tf03rb0jzw194l0rl5"
    client = LoopsClient.client
    one_key = client.idempotency_key(transactional_id, "one@example.com", @data_variables, seed)
    two_key = client.idempotency_key(transactional_id, "two@example.com", @data_variables, seed)
    stub_one = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("email" => "one@example.com"), headers: {"Idempotency-Key" => one_key})
      .to_return(status: 200, body: {success: true}.to_json)
    stub_two = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("email" => "two@example.com"), headers: {"Idempotency-Key" => two_key})
      .to_return(status: 200, body: {success: true}.to_json)

    deliver(build_mail(to: ["Owner <one@example.com>", "two@example.com", "one@example.com"], transactional_id: transactional_id, idempotency_seed: seed))

    assert_not_equal one_key, two_key
    assert_requested stub_one, times: 1
    assert_requested stub_two, times: 1
  end

  test "suppresses a same-key conflict without sending a duplicate recipient request" do
    seed = "charge:ch_123"
    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("email" => "user@example.com"))
      .to_return(status: 409)

    deliver(build_mail(to: ["User <user@example.com>", "user@example.com"], idempotency_seed: seed))

    assert_requested stub, times: 1
  end

  test "forwards Action Mailer attachments as strict-base64 Loops attachment objects" do
    attachment = {filename: "receipt.pdf", content_type: "application/pdf", content: "%PDF-1.4\nbinary"}
    expected_attachments = [{"filename" => "receipt.pdf", "contentType" => "application/pdf", "data" => Base64.strict_encode64(attachment[:content])}]
    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("attachments" => expected_attachments))
      .to_return(status: 200, body: {success: true}.to_json)

    deliver(build_mail(idempotency_seed: "charge:ch_123", attachments: [attachment]))

    assert_requested stub, times: 1
  end

  test "fails before HTTP when an attachment cannot produce a Loops payload" do
    attachment = {filename: "receipt.pdf", content_type: "application/pdf", content: ""}

    assert_raises(LoopsDelivery::InvalidAttachment) do
      deliver(build_mail(idempotency_seed: "charge:ch_123", attachments: [attachment]))
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
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

  test "fails loudly before any request when the billing idempotency seed header is missing or blank" do
    assert_raises(LoopsDelivery::MissingHeader) do
      deliver(build_mail(transactional_id: "cmsdrk6tf03rb0jzw194l0rl5"))
    end
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"

    assert_raises(LoopsDelivery::MissingHeader) do
      deliver(build_mail(transactional_id: "cmsdrk6tf03rb0jzw194l0rl5", idempotency_seed: " "))
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
