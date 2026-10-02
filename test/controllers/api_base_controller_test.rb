require "test_helper"

class ApiBaseControllerTest < ActionDispatch::IntegrationTest
  test "return 401 if not logged in" do
    get api_v1_me_url
    assert_response :unauthorized
  end

  test "successful when user logged in" do
    get api_v1_me_url, headers: {Authorization: "token #{users(:one).api_tokens.first.token}"}
    assert_response :success

    # Doesn't set Devise cookies
    assert_nil session["warden.user.user.key"]
  end

  test "token use is recorded at most every five minutes" do
    token = api_tokens(:one)

    freeze_time do
      token.update_column(:last_used_at, 1.minute.ago)
      recently_used_at = token.reload.last_used_at

      get api_v1_me_url, headers: {Authorization: "token #{token.token}"}

      assert_response :success
      assert_equal recently_used_at, token.reload.last_used_at

      token.update_column(:last_used_at, 10.minutes.ago)

      get api_v1_me_url, headers: {Authorization: "token #{token.token}"}

      assert_response :success
      assert_equal Time.current, token.reload.last_used_at
    end
  end
end
