require "application_system_test_case"

class TimeOffSystemTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    login_as users(:one), scope: :user
    @year = school_years(:company)
  end

  test "new time off starts and ends today" do
    open_add_time_off
    within("dialog[open]") do
      assert_field "Start", with: "2026-10-17"
      assert_field "End", with: "2026-10-17"
    end
  end

  test "moving Start beyond End moves End to match" do
    open_add_time_off
    within("dialog[open]") do
      set_date "break_starts_on", "2026-10-21"
      assert_field "End", with: "2026-10-21"
    end
  end

  test "moving Start preserves a later End" do
    open_add_time_off
    within("dialog[open]") do
      set_date "break_ends_on", "2026-10-25"
      set_date "break_starts_on", "2026-10-21"
      assert_field "End", with: "2026-10-25"
      set_date "break_starts_on", "2026-10-18"
      assert_field "End", with: "2026-10-25"
    end
  end

  test "invalid time off keeps entered values and errors inside its modal" do
    open_add_time_off
    within("dialog[open]") do
      fill_in "Name", with: " "
      set_date "break_starts_on", "2026-10-21"
      set_date "break_ends_on", "2026-10-25"
      click_button "Add time off"
      assert_text "Add a name."
      assert_field "Name", with: " "
      assert_field "Start", with: "2026-10-21"
      assert_field "End", with: "2026-10-25"
    end
  end

  test "closing a changed time off asks before discarding and keeps the draft" do
    open_add_time_off
    within("dialog[open]") do
      fill_in "Name", with: "Autumn break"
      click_button "Cancel"
      assert_text "Discard your changes?"
      click_button "Keep editing"
      assert_field "Name", with: "Autumn break"
      click_button "Cancel"
      click_button "Discard", exact: true
    end
    assert_no_selector "dialog[open]"
    assert_not @year.breaks.exists?(name: "Autumn break")
  end

  test "underway time off locks Start explains editing and hides Delete" do
    entry = nil
    travel_to Time.utc(2026, 10, 1, 12) do
      entry = @year.breaks.create!(name: "Autumn break", starts_on: "2026-10-16", ends_on: "2026-10-21", source: "added")
    end
    visit planner_school_year_path
    find("[data-time-off='#{entry.id}'] button").click
    within("dialog[open]") do
      assert_text "Edit time off"
      assert_field "Start", with: "2026-10-16", disabled: true
      assert_text "Already started. You can change the end date."
      assert_no_button "Delete time off"
      set_date "break_ends_on", "2026-10-22"
      wait_for_turbo_navigation { click_button "Save" }
    end
    assert_no_selector "dialog[open]"
    assert_selector "[role='status']", text: "Saved."
    assert_selector "[data-time-off='#{entry.id}']", text: "16–22 Oct"
    assert_equal Date.new(2026, 10, 16), entry.reload.starts_on
    assert_equal Date.new(2026, 10, 22), entry.ends_on
  end

  test "an overlap offers Replace it in the same modal and replaces the future entry" do
    entry = @year.breaks.create!(name: "Teacher day", starts_on: "2026-10-20", ends_on: "2026-10-20")
    open_add_time_off
    within("dialog[open]") do
      fill_in "Name", with: "Fall trip"
      set_date "break_starts_on", "2026-10-19"
      set_date "break_ends_on", "2026-10-21"
      click_button "Add time off"
      assert_text "This overlaps Teacher day (20 Oct)."
      assert_field "Name", with: "Fall trip"
      assert_field "Start", with: "2026-10-19"
      assert_no_button "Add time off"
      wait_for_turbo_navigation { click_button "Replace it" }
    end
    assert_no_selector "dialog[open]"
    assert_selector "[data-time-off]", text: "Fall trip"
    assert_not @year.breaks.exists?(id: entry.id)
  end

  test "deleting time off offers Undo in a toast that brings it back" do
    entry = @year.breaks.create!(name: "Teacher day", starts_on: "2026-10-20", ends_on: "2026-10-20", source: "added")
    visit planner_school_year_path
    find("[data-time-off='#{entry.id}'] button").click
    within("dialog[open]") do
      wait_for_turbo_navigation { click_button "Delete time off" }
    end
    assert_selector "[role='status']", text: "Time off removed"
    assert_no_selector "[data-time-off]", text: "Teacher day"
    assert_not @year.breaks.exists?(id: entry.id)
    wait_for_turbo_navigation { click_button "Undo" }
    assert_selector "[data-time-off]", text: "Teacher day"
    assert_equal 1, @year.breaks.where(name: "Teacher day").count
  end

  test "Undo that no longer fits explains why inside School year" do
    entry = @year.breaks.create!(name: "Teacher day", starts_on: "2026-10-20", ends_on: "2026-10-20", source: "added")
    visit planner_school_year_path
    find("[data-time-off='#{entry.id}'] button").click
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Delete time off" } }
    assert_selector "[role='status']", text: "Time off removed"
    @year.breaks.create!(name: "Co-op day", starts_on: "2026-10-20", ends_on: "2026-10-21")
    wait_for_turbo_navigation { click_button "Undo" }
    assert_selector "#time-off-restore-error", text: "We couldn't restore Teacher day. It overlaps Co-op day."
    assert_not @year.breaks.exists?(name: "Teacher day")
  end

  private

  def open_add_time_off
    visit planner_school_year_path
    first("button", text: "Add time off", exact_text: true).click
    assert_selector "dialog[open] #break_name"
  end

  def set_date(id, value)
    page.execute_script(<<~JS, find("##{id}"), value)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }));
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end
end
