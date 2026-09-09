require "test_helper"

class Users::SignupCompletionGateTest < ActionDispatch::IntegrationTest
  test "pending users are sent to signup completion before normal GET requests" do
    sign_in users(:oauth_signup_pending)
    assert_predicate users(:oauth_signup_pending), :signup_completion_required?

    get root_path

    assert_redirected_to signup_completion_path
    assert_equal root_path, controller.session["user_return_to"]
  end

  test "users without a pending signup can visit normal pages" do
    sign_in users(:one)

    get root_path

    assert_response :success
  end

  test "Devise pages are not intercepted" do
    sign_in users(:oauth_signup_pending)

    get new_user_session_path

    assert_not_equal signup_completion_path, response.location
  end

  test "sign out is not blocked" do
    sign_in users(:oauth_signup_pending)

    delete destroy_user_session_path

    assert_redirected_to root_path
  end
end
