require "test_helper"

class MeControllerTest < ActionDispatch::IntegrationTest
  test "returns current user details" do
    get api_v1_me_url, headers: {Authorization: "token #{user.api_tokens.first.token}"}
    assert_response :success

    assert_equal user.name, response.parsed_body["name"]
  end

  test "blocks an owner from deleting their login while another parent exists" do
    delete api_v1_me_url, headers: {Authorization: "token #{user.api_tokens.first.token}"}

    assert_response :unprocessable_content
  end

  test "allows a non-owner parent to delete their login" do
    parent = users(:two)
    assert_difference "User.count", -1 do
      delete api_v1_me_url, headers: {Authorization: "token #{parent.api_tokens.first.token}"}
      assert_response :success
    end
  end

  def user
    @user ||= users(:one)
  end
end
