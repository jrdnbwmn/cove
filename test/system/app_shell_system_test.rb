require "application_system_test_case"

class AppShellSystemTest < ApplicationSystemTestCase
  test "signed out visitor can use the primary navigation" do
    visit root_path

    assert_selector "header nav[data-controller='toggle']"
    assert_link Jumpstart.config.application_name, href: root_path
    assert_link I18n.t("application.left_nav.pricing"), href: pricing_path
    assert_link I18n.t("application.right_nav.log_in"), href: new_user_session_path
    assert_link I18n.t("application.right_nav.sign_up"), href: new_user_registration_path
  end

  test "mobile visitor can reveal the primary navigation" do
    page.current_window.resize_to(375, 900)
    visit root_path

    assert_selector "[data-toggle-target='toggleable']", visible: :all
    assert_no_selector "[data-toggle-target='toggleable']", visible: true

    find("button[aria-label='Open navigation']").click

    assert_selector "[data-toggle-target='toggleable']", visible: true
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "signed in user can switch accounts from the account menu" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='Account Menu']").click
    assert_selector "dialog[open]", text: accounts(:company).name

    within "dialog[open]" do
      click_button accounts(:company).name
    end

    assert_selector "button[aria-label='Account Menu']", text: accounts(:company).name
  end

  test "signed in user can open the user menu" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='User Menu']").click

    assert_selector "dialog[open]", text: I18n.t("application.user_menu.profile")
  end

  test "signed in user can open notifications" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='Notifications']").click

    assert_selector "dialog[open] turbo-frame#notifications"
  end

  test "development user can open the development menu" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='Dev Menu']").click

    assert_selector "dialog[open]", text: "Configuration"
  end

  test "signing out shows an alert banner" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='User Menu']").click
    within "dialog[open]" do
      click_button I18n.t("application.user_menu.sign_out")
    end

    assert_selector "#flash .border-blue-200", text: I18n.t("devise.sessions.signed_out")
  end

  test "footer retains its public links" do
    visit root_path

    assert_link I18n.t("application.footer.announcements"), href: announcements_path
    assert_link I18n.t("application.footer.about"), href: about_path
    assert_link I18n.t("application.footer.privacy"), href: privacy_path
    assert_link I18n.t("application.footer.terms"), href: terms_path
  end
end
