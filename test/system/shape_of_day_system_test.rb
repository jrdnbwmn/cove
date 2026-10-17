require "application_system_test_case"

class ShapeOfDaySystemTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    login_as users(:one), scope: :user
    @year = school_years(:company)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1400, 1400)
  end

  [1400, 390].each do |width|
    test "parents can set change and clear the start time from either tab at #{width}px" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width == 390)

      [planner_path, planner_school_year_path].each do |path|
        @year.update!(school_starts_at: nil)
        visit path
        open_shape_of_day
        assert_start_time ""
        assert_text "Optional. Cove uses this to estimate times on your day."
        assert_phone_button_order if width == 390
        set_start_time "08:30"
        save_start_time(path)
        assert_equal "08:30", @year.reload.school_starts_at.strftime("%H:%M")

        open_shape_of_day
        assert_start_time "08:30"
        set_start_time "09:45"
        save_start_time(path)
        assert_equal "09:45", @year.reload.school_starts_at.strftime("%H:%M")

        open_shape_of_day
        assert_start_time "09:45"
        set_start_time ""
        save_start_time(path)
        assert_nil @year.reload.school_starts_at
      end
    end

    test "parents can cancel or keep their unsaved start time at #{width}px" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width == 390)
      @year.update!(school_starts_at: "08:30")
      visit planner_path
      open_shape_of_day
      within("dialog[open]") { click_button "Cancel" }
      assert_no_selector "dialog[open]"
      assert_equal "08:30", @year.reload.school_starts_at.strftime("%H:%M")

      open_shape_of_day
      set_start_time "09:45"
      within("dialog[open]") do
        click_button "Cancel"
        assert_text "Discard your changes?"
        click_button "Keep editing"
        assert_start_time "09:45"
        click_button "Cancel"
        click_button "Discard", exact: true
      end
      assert_no_selector "dialog[open]"
      assert_equal "08:30", @year.reload.school_starts_at.strftime("%H:%M")
    end
  end

  private

  def open_shape_of_day
    assert_button "Shape of the day", exact: true
    click_button "Shape of the day", exact: true
    assert_selector "dialog[open] #school_year_school_starts_at"
    assert_selector "dialog[open] h2", text: "Shape of the day", exact_text: true, count: 1
  end

  def set_start_time(value)
    find("#school_year_school_starts_at + .ts-wrapper .ts-control").click
    label = value.empty? ? "No usual start time" : I18n.l(Time.zone.parse(value), format: :friendly)
    find("dialog[open] .ts-dropdown input").set(label)
    assert_selector "dialog[open] .ts-dropdown .option", count: 1
    option = find("dialog[open] .ts-dropdown [data-value='#{value}']", text: label, exact_text: true)
    assert option.evaluate_script(<<~JS)
      (() => {
        const rect = this.getBoundingClientRect();
        const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
        return rect.left >= 0 && rect.right <= window.innerWidth &&
          rect.top >= 0 && rect.bottom <= window.innerHeight && this.contains(hit);
      })()
    JS
    option.click
    assert_start_time value
  end

  def assert_start_time(value)
    assert_selector "#school_year_school_starts_at option:checked", visible: :all do |option|
      option.value == value
    end
  end

  def save_start_time(path)
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Save" } }
    assert_no_selector "dialog[open]"
    assert_current_path path
    assert_selector "[role='status']", text: "Saved."
    assert_selector "h1", text: "Planner", exact_text: true
  end

  def assert_phone_button_order
    within("dialog[open]") do
      save = find_button("Save")
      cancel = find_button("Cancel", exact: true)
      assert_operator save.evaluate_script("this.getBoundingClientRect().top"), :<, cancel.evaluate_script("this.getBoundingClientRect().top")
    end
  end
end
