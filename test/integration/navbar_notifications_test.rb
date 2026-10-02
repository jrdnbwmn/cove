require "test_helper"

class NavbarNotificationsTest < ActionDispatch::IntegrationTest
  test "signed-in web page loads don't count notifications" do
    sign_in users(:one)

    queries = notification_queries { get root_path }

    assert_response :success
    assert_empty queries
  end

  test "Hotwire Native page loads still count notifications" do
    sign_in users(:one)

    queries = notification_queries { get root_path, headers: {HTTP_USER_AGENT: "Hotwire Native iOS"} }

    assert_response :success
    assert_not_empty queries
  end

  private

  def notification_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_event, _started, _finished, _id, payload|
      queries << payload[:sql] if payload[:sql].include?("noticed_notifications")
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
