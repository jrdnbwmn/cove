require "application_system_test_case"
require "tmpdir"

class DevClockSystemTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @directory = Dir.mktmpdir("cove-browser-clock")
    @path = Pathname.new(@directory).join("dev_today")
    @year = school_years(:company)
    login_as users(:one), scope: :user
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1400, 1400)
    FileUtils.remove_entry(@directory)
  end

  [1400, 390].each do |width|
    test "parents can set change and clear a shared pretend date at #{width}px" do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
        DevClock.stub(:path, @path) do
          page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width == 390)
          visit planner_school_year_path
          real_so_far = summary_so_far
          assert_no_selector "[data-dev-clock-strip]"
          visit dev_clock_path
          assert_text "Real today for your family: 17 Oct 2026"
          assert_text "Override: none"
          set_clock "2026-10-14"
          assert_text "Override: 14 Oct 2026"
          assert_field "Pretend date", with: "2026-10-14"
          assert_shell_fits
          page.execute_script("arguments[0].focus()", find_field("Pretend date"))
          assert_equal "date", page.evaluate_script("document.activeElement.id")

          visit planner_school_year_path
          assert_selector "[data-dev-clock-strip]", count: 1, text: "14 Oct 2026"
          assert_operator summary_so_far, :<, real_so_far
          assert_button "Shape of the day"
          assert_shell_fits
          within("[data-dev-clock-strip]") { click_link "Change" }
          assert_current_path dev_clock_path
          set_clock "2026-10-20"

          visit planner_school_year_path
          assert_operator summary_so_far, :>, real_so_far
          first("button", text: "Add time off", exact_text: true).click
          assert_selector "dialog[open] #break_name"
          within("dialog[open]") do
            fill_in "Name", with: "Pretend past day"
            set_date "break_starts_on", "2026-10-19"
            set_date "break_ends_on", "2026-10-19"
            click_button "Add time off"
            assert_text "Choose a start date from today on."
          end
          assert_not @year.breaks.exists?(name: "Pretend past day")

          visit dev_clock_path
          set_clock "2027-06-01"
          visit planner_school_year_path
          assert_text "This year has ended."
          assert_no_button "Shape of the day"
          assert_no_button "Edit year"
          assert_no_button "Add time off"
          visit planner_path
          assert_no_button "Shape of the day"
          within("[data-dev-clock-strip]") { wait_for_turbo_navigation { click_button "Clear" } }
          assert_current_path planner_path
          assert_no_selector "[data-dev-clock-strip]"
          assert_button "Shape of the day"
          assert_nil DevClock.today
          visit planner_school_year_path
          assert_equal real_so_far, summary_so_far
          assert_button "Edit year"
          assert_shell_fits
        end
      end
    end
  end

  private

  def set_clock(date)
    set_date "date", date
    wait_for_turbo_navigation { click_button "Set" }
    assert_current_path dev_clock_path
    assert_selector "[data-dev-clock-strip]"
  end

  def set_date(id, date)
    page.execute_script(<<~JS, find("##{id}"), date)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }));
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end

  def summary_so_far
    find("p", text: /so far/).text[/(\d+) so far/, 1].to_i
  end

  def assert_shell_fits
    assert_equal page.evaluate_script("window.innerWidth"), page.evaluate_script("document.documentElement.clientWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollHeight"), :<=, page.evaluate_script("window.innerHeight")
    main = find("main")
    assert_operator main.evaluate_script("this.getBoundingClientRect().bottom"), :<=, page.evaluate_script("window.innerHeight")
    if has_selector?("[data-dev-clock-strip]")
      assert_operator main.evaluate_script("this.getBoundingClientRect().top"), :>=, find("[data-dev-clock-strip]").evaluate_script("this.getBoundingClientRect().bottom")
    end
  end
end
