require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "user can request and reset a password with a valid token" do
    user = users(:one)

    post user_password_path, params: {user: {email: user.email}}

    assert_response :redirect
    assert user.reload.reset_password_sent_at.present?

    reset_password_token = user.send(:set_reset_password_token)

    put user_password_path, params: {user: {
      reset_password_token: reset_password_token,
      password: "new-password",
      password_confirmation: "new-password"
    }}

    assert_response :redirect
    assert user.reload.valid_password?("new-password")
  end
end
