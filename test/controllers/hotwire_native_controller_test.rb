require "test_helper"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  test "unauthenticated request redirects to login" do
    get "/account/password"
    assert_redirected_to new_user_session_path
  end

  test "unauthenticated hotwire native requests" do
    get "/account/password", headers: {HTTP_USER_AGENT: "Hotwire Native iOS"}
    assert_response :unauthorized
  end

  test "native path configurations omit the retired Notifications tab" do
    get hotwire_ios_path_configuration_path
    assert_response :success
    assert_not_includes response.parsed_body.fetch("settings").fetch("tabs").map { |tab| tab.fetch("title") }, "Notifications"

    get hotwire_android_path_configuration_path
    assert_response :success
    assert_not_includes JSON.parse(response.parsed_body.fetch("settings").fetch("tabs")).map { |tab| tab.fetch("title") }, "Notifications"
  end
end
