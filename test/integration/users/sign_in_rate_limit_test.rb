require "test_helper"

class SignInRateLimitTest < ActionDispatch::IntegrationTest
  test "OTP attempts are rate limited" do
    user = users(:twofactor)
    post user_session_path, params: {user: {email: user.email, password: UNIQUE_PASSWORD}}
    assert_response :unprocessable_content

    Users::SessionsController.cache_store.stub(:increment, 11) do
      post user_session_path, params: {otp_attempt: "123456"}
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("try_again_later"), flash[:alert]
    assert_nil session["warden.user.user.key"]
  end

  test "a valid OTP signs the user in" do
    user = users(:twofactor)
    post user_session_path, params: {user: {email: user.email, password: UNIQUE_PASSWORD}}
    assert_response :unprocessable_content

    post user_session_path, params: {otp_attempt: user.current_otp}

    assert_redirected_to root_path
    assert_not_nil session["warden.user.user.key"]
  end
end
