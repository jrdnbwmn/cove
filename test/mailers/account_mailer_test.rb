require "test_helper"

class AccountMailerTest < ActionMailer::TestCase
  # AIDEV-NOTE: subclass proves no ERB rendering occurs — its rendering hook raises if invoked.
  class ExplodingAccountMailer < AccountMailer
    def render_to_body(*)
      raise "template rendering should never be invoked for Loops-backed account mailers"
    end
  end

  setup do
    @account_invitation = account_invitations(:one)
    @account = accounts(:company)
    @user = @account.owner
  end

  test "invite carries the account-invite transactional ID and exactly its declared variables" do
    message = AccountMailer.with(account_invitation: @account_invitation).invite.message
    data_variables = JSON.parse(message["X-Loops-Data-Variables"].value)

    assert_equal "cmsdr01rw02s00j3ozshehy4f", message["X-Loops-Transactional-Id"].value
    assert_equal %w[account_name invitation_url inviter_name].sort, data_variables.keys.sort
    assert_equal @account_invitation.invited_by.name, data_variables["inviter_name"]
    assert_equal @account_invitation.account.name, data_variables["account_name"]
  end

  test "invite URL uses the real invitation route and contains the invitation token" do
    message = AccountMailer.with(account_invitation: @account_invitation).invite.message
    invitation_url = JSON.parse(message["X-Loops-Data-Variables"].value)["invitation_url"]

    expected_url = Rails.application.routes.url_helpers.account_invitation_url(
      @account_invitation,
      **Rails.application.config.action_mailer.default_url_options
    )
    assert_equal expected_url, invitation_url

    uri = URI.parse(invitation_url)
    recognized = Rails.application.routes.recognize_path(uri.path, method: :get)
    assert_equal "account_invitations", recognized[:controller]
    assert_equal "show", recognized[:action]
    assert_equal @account_invitation.token, recognized[:id]
  end

  test "invite uses Someone when the invitation has no inviter" do
    @account_invitation.update!(invited_by: nil)

    message = AccountMailer.with(account_invitation: @account_invitation).invite.message
    data_variables = JSON.parse(message["X-Loops-Data-Variables"].value)

    assert_equal "Someone", data_variables["inviter_name"]
  end

  test "invite preserves the recipient and support sender metadata" do
    message = AccountMailer.with(account_invitation: @account_invitation).invite.message

    assert_equal [@account_invitation.email], message.to
    assert_equal [Mail::Address.new(Jumpstart.config.support_email).address], message.from
  end

  test "cancellation_reason carries the cancellation-survey transactional ID and no variables" do
    message = AccountMailer.with(user: @user).cancellation_reason.message

    assert_equal "cmsdrmznp040g0jzsnkt9hpsa", message["X-Loops-Transactional-Id"].value
    assert_equal({}, JSON.parse(message["X-Loops-Data-Variables"].value))
  end

  test "cancellation_reason preserves recipient, support sender, and reply-to metadata" do
    message = AccountMailer.with(user: @user).cancellation_reason.message

    assert_equal [@user.email], message.to
    assert_equal [Mail::Address.new(Jumpstart.config.support_email).address], message.from
    assert_equal [Jumpstart.config.support_email], message.reply_to
  end

  test "both messages are empty and not multipart" do
    invite = AccountMailer.with(account_invitation: @account_invitation).invite.message
    cancellation = AccountMailer.with(user: @user).cancellation_reason.message

    [invite, cancellation].each do |message|
      assert_not message.multipart?
      assert_equal "", message.body.to_s
    end
  end

  test "both messages build when template rendering would raise" do
    invite = ExplodingAccountMailer.with(account_invitation: @account_invitation).invite.message
    cancellation = ExplodingAccountMailer.with(user: @user).cancellation_reason.message

    assert_equal "cmsdr01rw02s00j3ozshehy4f", invite["X-Loops-Transactional-Id"].value
    assert_equal "cmsdrmznp040g0jzsnkt9hpsa", cancellation["X-Loops-Transactional-Id"].value
  end

  test "missing mappings raise instead of building a fallback message" do
    missing_mappings = Struct.new(:transactional).new({})

    Rails.application.stub(:config_for, missing_mappings) do
      assert_raises(KeyError) { AccountMailer.with(account_invitation: @account_invitation).invite.message }
      assert_raises(KeyError) { AccountMailer.with(user: @user).cancellation_reason.message }
    end
  end
end
