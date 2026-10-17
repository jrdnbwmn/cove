require "test_helper"

class SchoolYearEndDatePreviewsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @year = school_years(:company)
    sign_in users(:one)
  end

  test "guests must sign in to preview an end date" do
    sign_out users(:one)
    get planner_school_year_end_date_preview_path(ends_on: "2027-06-04")
    assert_redirected_to new_user_session_path
  end

  test "a later end date shows how many school days it adds" do
    get planner_school_year_end_date_preview_path(ends_on: "2027-06-04")
    assert_response :success
    assert_select "turbo-frame#end-date-preview", text: "Adds 5 school days."
  end

  test "a single added school day is singular" do
    get planner_school_year_end_date_preview_path(ends_on: "2027-05-31")
    assert_select "turbo-frame#end-date-preview", text: "Adds 1 school day."
  end

  test "an unchanged earlier or invalid end date shows nothing" do
    ["2027-05-28", "2027-05-01", "", "not-a-date", "2027-02-30"].each do |value|
      get planner_school_year_end_date_preview_path(ends_on: value)
      assert_response :success
      assert_select "turbo-frame#end-date-preview", text: ""
    end
    get planner_school_year_end_date_preview_path
    assert_select "turbo-frame#end-date-preview", text: ""
  end

  test "dates beyond the twelve month limit show nothing" do
    get planner_school_year_end_date_preview_path(ends_on: "2027-08-18")
    assert_select "turbo-frame#end-date-preview", text: ""
    get planner_school_year_end_date_preview_path(ends_on: "9999-12-31")
    assert_select "turbo-frame#end-date-preview", text: ""
  end

  test "the preview counts the signed-in family's own school days and saves nothing" do
    @year.update_columns(school_weekdays: [1])
    get planner_school_year_end_date_preview_path(ends_on: "2027-06-11")
    assert_select "turbo-frame#end-date-preview", text: "Adds 2 school days."
    assert_equal Date.new(2027, 5, 28), @year.reload.ends_on
  end
end
