require "test_helper"

class SettingsNavigationTest < ActionDispatch::IntegrationTest
  test "profile settings render horizontal semantic link tabs" do
    sign_in users(:one)

    get edit_user_registration_path

    assert_response :success
    assert_select "main > div.flex-1.overflow-y-auto", count: 1
    assert_select "main > div > div.app-content.p-6", count: 1
    assert_select "main > div > div.app-content > div[class~='max-w-[88rem]'] > div.settings-content", count: 1
    assert_select "h1", text: "Settings", count: 1
    assert_select "h1", count: 1
    assert_select "nav" do
      assert_select "a[href='#{edit_user_registration_path}'][aria-current='page']", text: I18n.t("application.account_navbar.profile")
      assert_select "a[href='#{edit_account_password_path}']", text: "Security"
      assert_select "a[href='#{user_connected_accounts_path}']", count: 0
      assert_select "a[href='#{account_path(accounts(:company))}']", text: I18n.t("application.account_navbar.family")
      assert_select "a[href='#{api_tokens_path}']", count: 0
    end
    assert_select "[data-controller='ui-tabs']", count: 0
    assert_select "[role='tablist'], [role='tab'], [role='tabpanel']", count: 0
    assert_select "nav .overflow-x-auto"
  end

  test "Security groups password, two-factor, and connected accounts" do
    sign_in users(:one)

    get edit_account_password_path

    assert_response :success
    assert_select "h1", count: 1
    assert_match "Two-factor authentication", response.body
    assert_match "Connected accounts", response.body
    assert_select "button[data-turbo-confirm*='Disconnect Google']", text: /Disconnect Google/
  end

  test "Billing renders as the active settings tab" do
    sign_in users(:subscribed)

    get billing_path

    assert_response :success
    assert_select "a[href='#{billing_path}'][aria-current='page']", text: I18n.t("application.account_navbar.billing")
  end
end
