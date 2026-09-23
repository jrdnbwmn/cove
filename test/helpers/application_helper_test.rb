require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    Current.account = accounts(:company)
  end

  test "dashboard is active only on the dashboard root, not on other pages" do
    request.path = "/"
    assert dashboard_nav_active?

    request.path = "/schedules"
    assert_not dashboard_nav_active?
  end

  test "each product page highlights only its own sidebar item" do
    request.path = "/schedules"
    assert schedules_nav_active?
    assert_not subjects_nav_active?
    assert_not students_nav_active?
    assert_not dashboard_nav_active?

    request.path = "/subjects"
    assert subjects_nav_active?
    assert_not schedules_nav_active?
    assert_not students_nav_active?

    request.path = "/students"
    assert students_nav_active?
    assert_not schedules_nav_active?
    assert_not subjects_nav_active?
  end

  test "settings stays highlighted across profile, password, and two-factor pages" do
    request.path = edit_user_registration_path
    assert settings_nav_active?
    assert profile_tab_active?
    assert_not password_tab_active?

    request.path = edit_account_password_path
    assert settings_nav_active?
    assert password_tab_active?
    assert_not profile_tab_active?

    request.path = user_two_factor_path
    assert settings_nav_active?
    assert password_tab_active?

    request.path = backup_codes_user_two_factor_path
    assert settings_nav_active?
    assert password_tab_active?
  end

  test "settings stays highlighted across connected accounts and billing descendants" do
    request.path = user_connected_accounts_path
    assert settings_nav_active?
    assert connected_accounts_tab_active?

    request.path = billing_path
    assert settings_nav_active?
    assert billing_tab_active?

    request.path = "#{billing_path}/subscriptions"
    assert settings_nav_active?
    assert billing_tab_active?
  end

  test "settings stays highlighted across family member pages" do
    family_path = account_path(accounts(:company))

    request.path = family_path
    assert settings_nav_active?
    assert family_tab_active?

    request.path = "#{family_path}/members"
    assert settings_nav_active?
    assert family_tab_active?

    request.path = "#{family_path}/invitations"
    assert family_tab_active?

    request.path = "#{family_path}/transfer"
    assert family_tab_active?
  end

  test "settings stays highlighted across api token pages" do
    request.path = api_tokens_path
    assert settings_nav_active?
    assert api_tokens_tab_active?

    request.path = "#{api_tokens_path}/new"
    assert api_tokens_tab_active?
  end

  test "referrals tab is inactive without raising when Refer is not defined" do
    assert_not defined?(Refer)

    request.path = "/referrals"
    assert_not referrals_tab_active?
  end

  test "invitation acceptance has no active sidebar item, despite sharing an /account prefix with Family" do
    request.path = "/account_invitations/abc123/edit"

    assert_not settings_nav_active?
    assert_not family_tab_active?
    assert_not dashboard_nav_active?
    assert_not schedules_nav_active?
    assert_not subjects_nav_active?
    assert_not students_nav_active?
  end

  test "pricing has no active sidebar item" do
    request.path = pricing_path

    assert_not settings_nav_active?
    assert_not dashboard_nav_active?
  end
end
