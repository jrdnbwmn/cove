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
end
