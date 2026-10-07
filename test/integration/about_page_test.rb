require "test_helper"

class AboutPageTest < ActionDispatch::IntegrationTest
  test "about page tells families what Cove is" do
    get about_path

    assert_response :success
    assert_select "h1", text: I18n.t("public.about.title")
    assert_select "h2", minimum: 4
    assert_select "a[href='mailto:support@covehomeschool.com']"
    assert_includes response.body, "Lay out classes and schedules for every learner in one place."
    assert_not_includes response.body, "Lay out subjects and schedules for every learner in one place."
    assert_not_includes response.body, "Last updated"
  end
end
