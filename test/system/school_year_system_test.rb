require "application_system_test_case"

class SchoolYearSystemTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    login_as users(:one), scope: :user
    @year = school_years(:company)
  end

  test "moving Ends later shows how many school days it adds" do
    open_edit_year
    set_date "school_year_ends_on", "2027-06-04"
    assert_selector "#end-date-preview", text: "Adds 5 school days."
    assert_equal 5, @year.added_days_if_ended_on(Date.new(2027, 6, 4))
  end

  test "a slow preview shows a skeleton and then the text" do
    open_edit_year
    hold_preview_responses 1
    set_date "school_year_ends_on", "2027-06-04"
    assert_selector "dialog[open] [data-school-year-preview-target='skeleton']", visible: :visible
    assert_no_selector "#end-date-preview", text: "Adds"
    wait_for_held_preview
    release_preview_response 0
    assert_selector "#end-date-preview", text: "Adds 5 school days."
    assert_no_selector "[data-school-year-preview-target='skeleton']", visible: :visible
  end

  test "the latest Ends wins when an earlier response arrives late" do
    open_edit_year
    hold_preview_responses 1
    set_date "school_year_ends_on", "2027-06-04"
    set_date "school_year_ends_on", "2027-06-11"
    assert_selector "#end-date-preview", text: "Adds 10 school days."
    release_preview_response 0
    wait_a_moment
    assert_selector "#end-date-preview", text: "Adds 10 school days."
    assert_no_selector "#end-date-preview", text: "Adds 5 school days."
  end

  test "moving Ends earlier or clearing it shows nothing" do
    open_edit_year
    set_date "school_year_ends_on", "2027-06-04"
    assert_selector "#end-date-preview", text: "Adds 5 school days."
    set_date "school_year_ends_on", "2027-05-21"
    assert_no_selector "#end-date-preview", text: "Adds"
    set_date "school_year_ends_on", "2027-06-04"
    assert_selector "#end-date-preview", text: "Adds 5 school days."
    set_date "school_year_ends_on", ""
    assert_no_selector "#end-date-preview", text: "Adds"
    assert_no_selector "[data-school-year-preview-target='skeleton']", visible: :visible
  end

  test "the preview does not clear the unsaved changes prompt" do
    open_edit_year
    set_date "school_year_ends_on", "2027-06-04"
    assert_selector "#end-date-preview", text: "Adds 5 school days."
    within("dialog[open]") { click_button "Cancel" }
    assert_text "Discard your changes?"
  end

  test "school days can be toggled from the keyboard and saved" do
    open_edit_year
    friday = day_input("Fri")
    assert friday.checked?
    page.execute_script("arguments[0].focus()", friday)
    page.driver.browser.action.send_keys(" ").perform
    assert_not friday.checked?
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Save" } }
    assert_no_selector "dialog[open]"
    assert_equal [1, 2, 3, 4], @year.reload.school_weekdays
  end

  test "a family's first year can still move Starts earlier" do
    open_edit_year
    within("dialog[open]") do
      assert_field "Starts", with: "2026-08-17", disabled: false
      assert_text "The year has started. You can only move the start earlier."
    end
  end

  test "a later year locks Starts once it has begun" do
    @year.update!(tracked_from: nil)
    open_edit_year
    within("dialog[open]") do
      assert_field "Starts", with: "2026-08-17", disabled: true
      assert_text "The year has started."
      assert_no_text "You can only move the start earlier."
    end
  end

  test "choosing no school days shows an inline error and keeps the entered values" do
    open_edit_year
    within("dialog[open]") do
      set_date "school_year_ends_on", "2027-06-04"
      %w[Mon Tue Wed Thu Fri].each { |day| find("label", text: day, exact_text: true).click }
      click_button "Save"
      assert_text "Choose at least one school day."
      assert_field "Ends", with: "2027-06-04"
    end
    assert_selector "dialog[open]"
    assert_equal [1, 2, 3, 4, 5], @year.reload.school_weekdays
  end

  test "saving a later end updates the summary and keeps the past school day count" do
    visit planner_school_year_path
    before = summary_counts
    open_edit_year(visit: false)
    set_date "school_year_ends_on", "2027-06-04"
    assert_selector "#end-date-preview", text: "Adds 5 school days."
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Save" } }
    assert_no_selector "dialog[open]"
    assert_selector "p", text: /#{@year.school_days_count + 5} school days/
    after = summary_counts
    assert_equal before[:so_far], after[:so_far]
    assert_equal before[:to_go] + 5, after[:to_go]
  end

  test "changing school days applies from today and keeps the past school day count" do
    visit planner_school_year_path
    before = summary_counts
    open_edit_year(visit: false)
    find("label", text: "Fri", exact_text: true).click
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Save" } }
    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Mon–Thu"
    after = summary_counts
    assert_equal before[:so_far], after[:so_far]
    assert_operator after[:to_go], :<, before[:to_go]
  end

  private

  def open_edit_year(visit: true)
    visit planner_school_year_path if visit
    first("button", text: "Edit year", exact_text: true).click
    assert_selector "dialog[open] #school_year_ends_on"
  end

  def summary_counts
    text = find("p", text: /so far/).text
    {so_far: text[/(\d+) so far/, 1].to_i, to_go: text[/(\d+) to go/, 1].to_i}
  end

  def day_input(day)
    find("##{find("label", text: day, exact_text: true)[:for]}", visible: :all)
  end

  def set_date(id, value)
    page.execute_script(<<~JS, find("##{id}"), value)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }));
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end

  # Delays the first `count` preview responses until release_preview_response is called.
  def hold_preview_responses(count)
    page.execute_script(<<~JS, count)
      window.__heldPreviews = []
      window.__holdPreviewCount = arguments[0]
      const originalFetch = window.fetch
      window.fetch = (input, options) => {
        const url = new URL(typeof input === "string" ? input : input.url, window.location.href)
        const result = originalFetch(input, options)
        if (url.pathname !== "/planner/school_year/end_date_preview" || window.__holdPreviewCount <= 0) return result
        window.__holdPreviewCount -= 1
        return result.then((response) => new Promise((resolve) => window.__heldPreviews.push(() => resolve(response))))
      }
    JS
  end

  # Turbo may already have aborted the held request when the newer one started, so there may be nothing to release.
  def release_preview_response(index)
    page.execute_script("window.__heldPreviews[#{index}]?.()")
  end

  def wait_for_held_preview
    page.document.synchronize { raise Capybara::ExpectationNotMet, "no held response" unless page.evaluate_script("window.__heldPreviews.length > 0") }
  end

  def wait_a_moment
    page.evaluate_async_script("const done = arguments[0]; setTimeout(done, 300)")
  end
end
