require "test_helper"

class LoopsDeviseMailerTest < ActiveSupport::TestCase
  # AIDEV-NOTE: subclass proves no ERB rendering occurs — its rendering hook raises if invoked.
  class ExplodingLoopsDeviseMailer < LoopsDeviseMailer
    def render_to_body(*)
      raise "template rendering should never be invoked for Loops-backed Devise mailers"
    end
  end

  setup do
    @user = users(:one)
    @token = "raw-reset-token"
  end

  test "config/loops.yml exposes every checked-in Devise and billing transactional mapping" do
    transactional = Rails.application.config_for(:loops).transactional

    assert_equal "cmsdnzduk02k40jx72rv3uwe2", transactional[:reset_password_instructions]
    assert_equal "cmsdo8ixv001e0j1zu027i3s7", transactional[:password_change]
    assert_equal "cmsdrk6tf03rb0jzw194l0rl5", transactional[:receipt]
    assert_equal "cmsdrk8f603rc0jzn1pmslh4m", transactional[:refund]
    assert_equal "cmsdru6vf04dv0j15pwbonmxs", transactional[:subscription_renewing]
    assert_equal "cmsdrxthi04p90jzc3bwkq7kj", transactional[:payment_action_required]
    assert_equal "cmsdrxtnb04qk0j3oclaszs7k", transactional[:payment_failed]
    assert_equal "cmsdru71a04c50jzw6rqtt95u", transactional[:subscription_trial_will_end]
    assert_equal "cmsdru76v04ep0jw7xrbb236w", transactional[:subscription_trial_ended]
    assert_equal %i[
      reset_password_instructions
      password_change
      receipt
      refund
      subscription_renewing
      payment_action_required
      payment_failed
      subscription_trial_will_end
      subscription_trial_ended
    ], transactional.keys
  end

  test "reset_password_instructions carries the Loops transactional id header" do
    message = LoopsDeviseMailer.reset_password_instructions(@user, @token).message

    assert_equal "cmsdnzduk02k40jx72rv3uwe2", message["X-Loops-Transactional-Id"].value
  end

  test "reset_password_instructions data variables contain exactly recipient_email and reset_password_url" do
    message = LoopsDeviseMailer.reset_password_instructions(@user, @token).message
    data_variables = JSON.parse(message["X-Loops-Data-Variables"].value)

    assert_equal %w[recipient_email reset_password_url].sort, data_variables.keys.sort
    assert_equal @user.email, data_variables["recipient_email"]
  end

  test "reset_password_instructions reset_password_url matches the real edit-password route helper" do
    message = LoopsDeviseMailer.reset_password_instructions(@user, @token).message
    data_variables = JSON.parse(message["X-Loops-Data-Variables"].value)

    expected_url = Rails.application.routes.url_helpers.edit_user_password_url(
      @user, reset_password_token: @token, **Rails.application.config.action_mailer.default_url_options
    )
    assert_equal expected_url, data_variables["reset_password_url"]

    uri = URI.parse(data_variables["reset_password_url"])
    recognized = Rails.application.routes.recognize_path(uri.path, method: :get)
    assert_equal "users/passwords", recognized[:controller]
    assert_equal "edit", recognized[:action]

    query_params = Rack::Utils.parse_nested_query(uri.query)
    assert_equal @token, query_params["reset_password_token"]
  end

  test "reset_password_instructions message body is empty and not multipart" do
    message = LoopsDeviseMailer.reset_password_instructions(@user, @token).message

    assert_not message.multipart?
    assert_equal "", message.body.to_s
  end

  test "reset_password_instructions builds successfully even when template rendering would raise" do
    message = ExplodingLoopsDeviseMailer.reset_password_instructions(@user, @token).message

    assert_equal "cmsdnzduk02k40jx72rv3uwe2", message["X-Loops-Transactional-Id"].value
  end

  test "password_change carries the Loops transactional id header" do
    message = LoopsDeviseMailer.password_change(@user).message

    assert_equal "cmsdo8ixv001e0j1zu027i3s7", message["X-Loops-Transactional-Id"].value
  end

  test "password_change data variables contain exactly recipient_email" do
    message = LoopsDeviseMailer.password_change(@user).message
    data_variables = JSON.parse(message["X-Loops-Data-Variables"].value)

    assert_equal %w[recipient_email], data_variables.keys
    assert_equal @user.email, data_variables["recipient_email"]
  end

  test "password_change message body is empty and not multipart" do
    message = LoopsDeviseMailer.password_change(@user).message

    assert_not message.multipart?
    assert_equal "", message.body.to_s
  end

  test "password_change builds successfully even when template rendering would raise" do
    message = ExplodingLoopsDeviseMailer.password_change(@user).message

    assert_equal "cmsdo8ixv001e0j1zu027i3s7", message["X-Loops-Transactional-Id"].value
  end
end
