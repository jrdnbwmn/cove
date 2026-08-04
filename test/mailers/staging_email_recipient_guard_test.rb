require "test_helper"

class StagingEmailRecipientGuardTest < ActiveSupport::TestCase
  def build_mail(to: ["allowed@example.com"], cc: nil, bcc: nil)
    Mail.new(
      to: to,
      cc: cc,
      bcc: bcc,
      from: "noreply@example.com",
      subject: "test",
      body: ""
    )
  end

  test "missing, blank, comma-only, and invalid allowlists fail closed" do
    [nil, "", "   ", ", ,", "allowed@example.com, not-an-email"].each do |allowlist|
      error = assert_raises(StagingEmailRecipientGuard::InvalidAllowlist) do
        StagingEmailRecipientGuard.configure!(allowlist)
      end

      assert_match(/allowlist/i, error.message)
    end
  end

  test "trims entries and compares recipients case-insensitively" do
    guard = StagingEmailRecipientGuard.configure!(" Allowed@Example.com , second@example.com ")

    assert_nil guard.delivering_email(build_mail(to: ["allowed@example.com"], cc: ["SECOND@example.com"]))
  end

  test "does not infer plus aliases or domain patterns" do
    guard = StagingEmailRecipientGuard.configure!("allowed@example.com, *@example.org")

    error = assert_raises(StagingEmailRecipientGuard::BlockedRecipient) do
      guard.delivering_email(build_mail(to: ["allowed+staging@example.com"]))
    end

    assert_equal "allowed+staging@example.com", error.recipient
    assert_not_includes error.message, "allowed@example.com"

    domain_error = assert_raises(StagingEmailRecipientGuard::BlockedRecipient) do
      guard.delivering_email(build_mail(to: ["anyone@example.org"]))
    end
    assert_equal "anyone@example.org", domain_error.recipient
  end

  test "allows exact To, CC, and BCC recipients" do
    guard = StagingEmailRecipientGuard.configure!("to@example.com,cc@example.com,bcc@example.com")

    assert_nil guard.delivering_email(build_mail(to: ["to@example.com"], cc: ["cc@example.com"], bcc: ["bcc@example.com"]))
  end

  test "blocks a recipient in every address field" do
    guard = StagingEmailRecipientGuard.configure!("allowed@example.com")

    {to: ["blocked-to@example.com"], cc: ["blocked-cc@example.com"], bcc: ["blocked-bcc@example.com"]}.each do |field, recipients|
      error = assert_raises(StagingEmailRecipientGuard::BlockedRecipient) do
        guard.delivering_email(build_mail(**{field => recipients}))
      end

      assert_equal recipients.first, error.recipient
    end
  end

  test "blocks mixed recipients before Loops receives a request" do
    with_registered_guard("allowed@example.com") do
      stub_request(:post, "https://app.loops.so/api/v1/transactional")

      assert_raises(StagingEmailRecipientGuard::BlockedRecipient) do
        deliver_password_change_to("allowed@example.com", "blocked@example.com")
      end

      assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
    end
  end

  test "delivers an entirely allowed message through Loops" do
    with_registered_guard("allowed@example.com") do
      stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
        .with(body: hash_including("email" => "allowed@example.com"))
        .to_return(status: 200, body: {success: true}.to_json)

      deliver_password_change_to("allowed@example.com")

      assert_requested stub, times: 1
    end
  end

  private

  def deliver_password_change_to(*emails)
    user = users(:one)
    user.email = emails.first
    original_delivery_method = LoopsDeviseMailer.delivery_method
    LoopsDeviseMailer.delivery_method = :loops
    delivery = LoopsDeviseMailer.password_change(user)
    delivery.message.to = emails

    Rails.application.credentials.stub(:dig, "test-token") { delivery.deliver_now }
  ensure
    LoopsDeviseMailer.delivery_method = original_delivery_method
  end

  def with_registered_guard(allowlist)
    StagingEmailRecipientGuard.configure!(allowlist)
    Mail.register_interceptor(StagingEmailRecipientGuard)
    yield
  ensure
    Mail.unregister_interceptor(StagingEmailRecipientGuard)
  end
end
