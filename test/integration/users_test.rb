require "test_helper"

class Jumpstart::UsersTest < ActionDispatch::IntegrationTest
  test "owner with another parent cannot delete their login" do
    sign_in users(:one)
    assert_no_difference "User.count" do
      delete "/users"
    end
    assert_redirected_to edit_user_registration_path
  end

  test "invalid time zones are handled safely" do
    user = users(:one)
    user.update! time_zone: "invalid"

    sign_in user
    get root_path
    assert_response :success
  end
end
