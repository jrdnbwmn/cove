require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  # AIDEV-NOTE: subclass proves no ERB rendering occurs — its rendering hook raises if invoked.
  class ExplodingUserMailer < UserMailer
    def render_to_body(*)
      raise "template rendering should never be invoked for Loops-backed user mailers"
    end
  end

  setup do
    @user = users(:one)
  end

  test "account-created carries the Loops transactional ID and exactly its declared variables" do
    message = UserMailer.with(user: @user).account_created.message
    data_variables = JSON.parse(message["X-Loops-Data-Variables"].value)

    assert_equal "cmt95d4t100gq0jyvqpknv5vi", message["X-Loops-Transactional-Id"].value
    assert_equal %w[recipient_email sign_in_url], data_variables.keys.sort
    assert_equal @user.email, data_variables["recipient_email"]
  end

  test "account-created uses the real sign-in route" do
    message = UserMailer.with(user: @user).account_created.message
    sign_in_url = JSON.parse(message["X-Loops-Data-Variables"].value)["sign_in_url"]

    expected_url = Rails.application.routes.url_helpers.new_user_session_url(
      **Rails.application.config.action_mailer.default_url_options
    )
    assert_equal expected_url, sign_in_url

    uri = URI.parse(sign_in_url)
    recognized = Rails.application.routes.recognize_path(uri.path, method: :get)
    assert_equal "users/sessions", recognized[:controller]
    assert_equal "new", recognized[:action]
  end

  test "account-created preserves recipient, support sender, and reply-to metadata" do
    message = UserMailer.with(user: @user).account_created.message

    assert_equal [@user.email], message.to
    assert_equal [Mail::Address.new(Jumpstart.config.support_email).address], message.from
    assert_equal [Jumpstart.config.support_email], message.reply_to
  end

  test "account-created is empty and not multipart" do
    message = UserMailer.with(user: @user).account_created.message

    assert_not message.multipart?
    assert_equal "", message.body.to_s
  end

  test "account-created builds successfully when template rendering would raise" do
    message = ExplodingUserMailer.with(user: @user).account_created.message

    assert_equal "cmt95d4t100gq0jyvqpknv5vi", message["X-Loops-Transactional-Id"].value
  end

  test "missing account-created mapping raises instead of building a fallback message" do
    missing_mappings = Struct.new(:transactional).new({})

    Rails.application.stub(:config_for, missing_mappings) do
      assert_raises(KeyError) { UserMailer.with(user: @user).account_created.message }
    end
  end
end
