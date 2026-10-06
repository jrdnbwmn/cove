require "test_helper"

class Users::TwoFactorTest < ActionDispatch::IntegrationTest
  test "viewing backup codes does not create two-factor secrets" do
    user = users(:one)
    sign_in user

    assert_nil user.otp_secret
    assert_empty user.otp_backup_codes

    get backup_codes_user_two_factor_path

    assert_response :success
    assert_nil user.reload.otp_secret
    assert_empty user.otp_backup_codes
  end

  test "starting two-factor setup creates backup codes and a secret" do
    user = users(:one)
    sign_in user

    post backup_codes_user_two_factor_path

    assert_response :success
    assert_predicate user.reload.otp_secret, :present?
    assert_predicate user.otp_backup_codes, :present?
    assert_select "turbo-frame#modal-lazy-content"
  end

  test "the verify step shows the authenticator QR code and setup key" do
    user = users(:one)
    sign_in user
    post backup_codes_user_two_factor_path

    get verify_user_two_factor_path

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content svg"
    assert_match user.reload.otp_app_code, response.body
  end

  test "the verify step without a started setup sends the user back to Security" do
    sign_in users(:one)

    get verify_user_two_factor_path

    assert_redirected_to edit_account_password_path
  end
end
