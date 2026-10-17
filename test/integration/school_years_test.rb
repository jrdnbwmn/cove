require "test_helper"

class SchoolYearsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @year = school_years(:company)
    sign_in users(:one)
  end

  test "guests must sign in to view or change a year" do
    sign_out users(:one)
    [planner_school_year_path, edit_planner_school_year_path].each do |path|
      get path
      assert_redirected_to new_user_session_path
    end
    patch planner_school_year_path, params: {school_year: {ends_on: "2027-05-31"}}
    assert_redirected_to new_user_session_path
  end

  test "School year keeps its full page and toasts when a modal form redirects to it" do
    get planner_school_year_path, headers: {"Turbo-Frame" => "modal-lazy-content"}
    assert_response :success
    assert_select "head link[data-turbo-track='reload']"
    assert_select "#toasts"
  end

  test "either parent can edit the family's year" do
    [users(:one), users(:two)].each do |parent|
      sign_in parent
      get edit_planner_school_year_path
      assert_response :success
      assert_select "turbo-frame#modal-lazy-content form[action=?]", planner_school_year_path
      assert_select "input[type=date][name='school_year[starts_on]']:not([disabled])"
      assert_select "fieldset legend", text: "School days"
      assert_select "input[type=checkbox][name='school_year[school_weekdays][]']", count: 7
      patch planner_school_year_path, params: {school_year: {ends_on: "2027-05-31", school_weekdays: ["", "1", "2", "3", "4"]}}
      assert_redirected_to planner_school_year_path
      assert_equal "Saved.", flash[:notice]
      assert_equal [1, 2, 3, 4], @year.reload.school_weekdays
      sign_out parent
    end
  end

  test "year changes cannot move ownership or overwrite protected fields" do
    original = @year.attributes.slice("account_id", "status", "tracked_from", "weekday_history", "school_starts_at")
    patch planner_school_year_path, params: {id: school_years(:one).id, school_year: {account_id: accounts(:one).id, status: "ended", tracked_from: "2026-10-17", weekday_history: [{through: "2026-10-16", days: [0]}], school_starts_at: "06:00", ends_on: "2027-05-31"}}
    assert_redirected_to planner_school_year_path
    assert_equal original, @year.reload.attributes.slice(*original.keys)
    assert_equal Date.new(2027, 5, 28), school_years(:one).reload.ends_on
  end

  test "invalid year values stay in the form with inline errors" do
    patch planner_school_year_path, params: {school_year: {ends_on: "2027-05-31", school_weekdays: [""]}}
    assert_response :unprocessable_content
    assert_select "input[name='school_year[ends_on]'][value='2027-05-31']"
    assert_select "p", text: "Choose at least one school day."
    assert_select "input[type=checkbox][checked]", count: 0
    assert_equal [1, 2, 3, 4, 5], @year.reload.school_weekdays
  end

  test "later-year Starts is locked after the year begins" do
    @year.update!(tracked_from: nil)
    get edit_planner_school_year_path
    assert_select "input[name='school_year[starts_on]'][disabled]"
    patch planner_school_year_path, params: {school_year: {starts_on: "2026-08-10"}}
    assert_response :unprocessable_content
    assert_equal Date.new(2026, 8, 17), @year.reload.starts_on
  end

  test "ended years reject editing and extending" do
    travel_to Time.utc(2027, 6, 1, 12) do
      get edit_planner_school_year_path
      assert_response :forbidden
      patch planner_school_year_path, params: {school_year: {ends_on: "2027-06-02"}}
      assert_response :unprocessable_content
      assert_equal Date.new(2027, 5, 28), @year.reload.ends_on
    end
  end

  test "a family without an active year cannot use another family's year" do
    @year.destroy!
    get edit_planner_school_year_path, params: {id: school_years(:one).id}
    assert_response :not_found
  end

  test "School year shares the Planner header and shows calculated counts inside its tab" do
    get planner_school_year_path
    assert_response :success
    assert_select "h1", text: "Planner", count: 1
    assert_select "nav a[href=?][aria-current=page]", planner_school_year_path, text: "School year"
    assert_select "nav a[href=?]:not([aria-current])", planner_path, text: "Schedule"
    assert_select "p", text: "Mon–Fri · 17 Aug 2026–28 May 2027 · #{@year.school_days_count} school days · #{@year.so_far_count} so far, #{@year.to_go_count} to go"
    assert_select "#time-off-restore-error[role=alert]"
  end

  test "empty time off explains what belongs here and offers an Add action" do
    get planner_school_year_path
    assert_select "h3", text: "No time off yet."
    assert_select "p", text: "Add some when you plan days off."
    assert_select "[data-ui-modal-turbo-frame-src-value=?] button", new_planner_school_year_break_path, text: "Add time off", count: 2
    assert_select "#time-off-inline-add", count: 0
  end

  test "time off rows are ordered and show escaped names and friendly date ranges" do
    winter = @year.breaks.create!(name: "Winter <script>break</script>", starts_on: "2026-12-21", ends_on: "2027-01-01", source: "added")
    thanksgiving = @year.breaks.create!(name: "Thanksgiving", starts_on: "2026-11-26", ends_on: "2026-11-26", source: "added")
    get planner_school_year_path
    assert_select "[data-time-off]" do |rows|
      assert_equal [thanksgiving.id.to_s, winter.id.to_s], rows.map { |row| row["data-time-off"] }
    end
    assert_select "[data-time-off=?] button", winter.id, text: "Winter <script>break</script>"
    assert_select "[data-time-off=?] script", winter.id, count: 0
    assert_select "[data-time-off=?] p", winter.id, text: "21 Dec 2026–1 Jan 2027"
    assert_select "[data-time-off=?] p", thanksgiving.id, text: "26 Nov"
    assert_select "#time-off-inline-add [data-ui-modal-turbo-frame-src-value=?] button", new_planner_school_year_break_path, text: "Add time off"
  end

  test "current and future time off open edit modals while past rows are plain" do
    past = current = nil
    travel_to Time.utc(2026, 9, 1, 12) do
      past = @year.breaks.create!(name: "Past", starts_on: "2026-09-14", ends_on: "2026-09-15", source: "added")
      current = @year.breaks.create!(name: "Current", starts_on: "2026-10-16", ends_on: "2026-10-20", source: "added")
    end
    future = @year.breaks.create!(name: "Future", starts_on: "2026-11-02", ends_on: "2026-11-03", source: "added")
    get planner_school_year_path
    [current, future].each do |entry|
      assert_select "[data-time-off=?] [data-ui-modal-turbo-frame-src-value=?] button[data-action='click->ui-modal#open:prevent']", entry.id, edit_planner_school_year_break_path(entry), text: entry.name
    end
    assert_select "[data-time-off=?]", past.id do
      assert_select "p", text: "Past"
      assert_select "button, a, [data-controller]", count: 0
    end
  end

  test "ended year preserves records and hides all edit and Add actions" do
    entry = @year.breaks.create!(name: "Winter", starts_on: "2026-12-21", ends_on: "2027-01-01", source: "added")
    travel_to Time.utc(2027, 6, 1, 12) do
      get planner_school_year_path
      assert_select "p", text: /This year has ended\./
      assert_select "p", text: "Planning next year is coming soon. Your records for this year are kept."
      assert_select "[data-time-off=?] p", entry.id, text: "Winter"
      assert_select "[data-ui-modal-turbo-frame-src-value]", count: 0
      assert_select "#time-off-inline-add", count: 0
    end
  end
end
