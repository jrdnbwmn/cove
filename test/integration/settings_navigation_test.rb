require "test_helper"

class SettingsNavigationTest < ActionDispatch::IntegrationTest
  test "profile settings render horizontal semantic link tabs" do
    sign_in users(:one)

    get edit_user_registration_path

    assert_response :success
    assert_select "main > div.flex-1.overflow-y-auto", count: 1
    assert_select "main > div > div.app-content.p-6", count: 1
    assert_select "main > div > div.app-content > div.p-0", count: 1
    assert_select "h1", text: "Settings", count: 1
    assert_select "nav" do
      assert_select "a[href='#{edit_user_registration_path}'][aria-current='page']", text: I18n.t("application.account_navbar.profile")
      assert_select "a[href='#{edit_account_password_path}']", text: I18n.t("application.account_navbar.password")
      assert_select "a[href='#{account_path(accounts(:company))}']", text: "Family"
    end
    assert_select "[data-controller='ui-tabs']", count: 0
    assert_select "[role='tablist'], [role='tab'], [role='tabpanel']", count: 0
    assert_select "nav .overflow-x-auto"
  end

  test "Billing renders as the active settings tab" do
    sign_in users(:subscribed)

    get billing_path

    assert_response :success
    assert_select "a[href='#{billing_path}'][aria-current='page']", text: I18n.t("application.account_navbar.billing")
  end
end
