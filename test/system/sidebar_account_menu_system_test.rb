require "application_system_test_case"
require "tmpdir"

class SidebarAccountMenuSystemTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    login_as users(:one), scope: :user
    page.current_window.resize_to(1400, 1000)
  end

  teardown { page.current_window.resize_to(1400, 1400) }

  [false, true].each do |pretending|
    test "the account menu stays at the bottom expanded and collapsed #{pretending ? "with" : "without"} the dev strip" do
      Dir.mktmpdir("cove-sidebar-clock") do |directory|
        Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
          DevClock.stub(:path, Pathname.new(directory).join("dev_today")) do
            DevClock.set(Date.new(2026, 10, 14)) if pretending
            visit planner_path
            assert_selector "[data-sidebar-target=desktopSidebar][open]"
            assert_account_menu_at_bottom
            find("button[aria-label='Collapse sidebar']").click
            assert_selector "button[aria-label='Expand sidebar']", visible: true
            assert_account_menu_at_bottom
            find("button[aria-label='Expand sidebar']").click
            assert_selector "button[aria-label='Collapse sidebar']", visible: true
            assert_account_menu_at_bottom
            find("button[aria-label='Account menu']", match: :first).click
            assert_selector "dialog[open]", text: "Settings"
            assert_operator page.evaluate_script("document.documentElement.scrollHeight"), :<=, page.evaluate_script("window.innerHeight")
          end
        end
      end
    end
  end

  private

  def assert_account_menu_at_bottom
    menu = find("button[aria-label='Account menu']", match: :first)
    gap = menu.evaluate_script("window.innerHeight - this.getBoundingClientRect().bottom")
    assert_operator gap, :<=, 24, "Account menu should sit within the sidebar’s bottom padding"
    assert_operator gap, :>=, 0
  end
end
