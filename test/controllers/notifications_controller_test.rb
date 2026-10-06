require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  test "notifications page is no longer routed" do
    get "/notifications"

    assert_response :not_found
  end
end
