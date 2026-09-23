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

  test "signed in user sees sidebar navigation without the retired shell" do
    login_as users(:one), scope: :user
    visit root_path

    assert_selector "[data-controller='sidebar']"
    assert_link "Home", href: user_root_path
    assert_link "Schedules", href: schedules_path
    assert_link "Subjects", href: subjects_path
    assert_link "Students", href: students_path
    assert_selector "a[href='#{user_root_path}'][aria-current='page']", count: 1
    assert_no_selector "nav[aria-label='Primary']"
    assert_no_selector "button[aria-label='Notifications']"
    assert_no_selector "footer"
  end

  test "admin sees a same-tab Admin sidebar link" do
    admin = users(:admin)
    admin.create_default_account
    login_as admin, scope: :user
    visit root_path

    assert_link "Admin", href: madmin_root_path
    assert_no_selector "a[href='#{madmin_root_path}'][target]"
  end

  test "signed in user can open the expanded account menu" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='Account menu']", match: :first).click

    assert_selector "dialog[open]", text: I18n.t("application.user_menu.profile")
    within "dialog[open]" do
      assert_link "Family", href: account_path(accounts(:company))
    end
  end

  test "signed in user can open the collapsed account menu" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='Collapse sidebar']").click
    assert_selector "button[aria-label='Expand sidebar']", visible: true

    find("button[aria-label='Account menu']", match: :first).click

    assert_selector "dialog[open]", text: I18n.t("application.user_menu.profile")
  end

  test "mobile drawer account menu opens its own menu" do
    login_as users(:one), scope: :user
    page.current_window.resize_to(375, 900)
    visit root_path

    find("button[aria-label='Open sidebar']").click
    within "[data-sidebar-target='mobileSidebar']" do
      find("button[aria-label='Account menu']").click
    end

    assert_selector "dialog[open]", text: I18n.t("application.user_menu.profile")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "collapsed sidebar survives Turbo navigation with the destination highlighted" do
    login_as users(:one), scope: :user
    visit root_path

    find("button[aria-label='Collapse sidebar']").click
    find("a[href='#{schedules_path}']", match: :first).click

    assert_current_path schedules_path
    assert_selector "button[aria-label='Expand sidebar']", visible: true
    assert_selector "a[href='#{schedules_path}'][aria-current='page']", count: 1
    assert_no_selector "a[href='#{user_root_path}'][aria-current='page']"
  end

  test "impersonating user sees sidebar controls and can stop" do
    admin = users(:admin)
    admin.create_default_account
    login_as admin, scope: :user
    visit madmin_user_path(users(:one))

    click_button "Impersonate"

    assert_selector "[data-testid='sidebar-impersonation']", text: users(:one).name
    find("button[aria-label='Collapse sidebar']").click
    assert_selector "button[aria-label='Account menu'][data-ui-tooltip-content*='Impersonating']"

    find("button[aria-label='Expand sidebar']").click
    page.current_window.resize_to(375, 900)
    find("button[aria-label='Open sidebar']").click
    within "[data-sidebar-target='mobileSidebar']" do
      assert_selector "[data-testid='sidebar-impersonation']"
    end
    page.current_window.resize_to(1400, 1400)
    click_button "Stop impersonating"

    assert_no_selector "[data-testid='sidebar-impersonation']"
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "footer retains its public links" do
    visit root_path

    assert_link I18n.t("application.footer.announcements"), href: announcements_path
    assert_link I18n.t("application.footer.about"), href: about_path
    assert_link I18n.t("application.footer.privacy"), href: privacy_path
    assert_link I18n.t("application.footer.terms"), href: terms_path
  end
end
