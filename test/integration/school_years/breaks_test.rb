require "test_helper"

class SchoolYearBreaksTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @year = school_years(:company)
    @entry = @year.breaks.create!(name: "Teacher day", starts_on: "2026-10-20", ends_on: "2026-10-20")
    sign_in users(:one)
  end

  test "guests must sign in to add time off" do
    sign_out users(:one)
    get new_planner_school_year_break_path
    assert_redirected_to new_user_session_path
    assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {break: valid_attributes} }
    assert_redirected_to new_user_session_path
  end

  test "either parent can add edit and delete time off" do
    [users(:one), users(:two)].each do |parent|
      sign_in parent
      assert_difference("@year.breaks.count", 1) { post planner_school_year_breaks_path, params: {break: valid_attributes} }
      assert_redirected_to planner_school_year_path
      assert_equal "Spring break added.", flash[:notice]
      entry = @year.breaks.find_by!(name: "Spring break")
      assert_equal "added", entry.source
      get edit_planner_school_year_break_path(entry)
      assert_select "turbo-frame#modal-lazy-content input[name='break[name]'][value='Spring break']"
      patch planner_school_year_break_path(entry), params: {break: {name: "Family break"}}
      assert_redirected_to planner_school_year_path
      assert_equal "Saved.", flash[:notice]
      assert_equal "Family break", entry.reload.name
      assert_difference("Break.count", -1) { delete planner_school_year_break_path(entry) }
      assert_redirected_to planner_school_year_path
      sign_out parent
    end
  end

  test "another family's time off is unavailable to edit change or delete" do
    entry = breaks(:winter)
    get edit_planner_school_year_break_path(entry)
    assert_response :not_found
    sign_in users(:one)
    patch planner_school_year_break_path(entry), params: {break: {name: "Changed"}}
    assert_response :not_found
    sign_in users(:one)
    assert_no_difference("Break.count") { delete planner_school_year_break_path(entry) }
    assert_response :not_found
  end

  test "submitted ownership and source cannot override the current family or added source" do
    post planner_school_year_breaks_path, params: {break: valid_attributes.merge(school_year_id: school_years(:one).id, source: "default")}
    assert_redirected_to planner_school_year_path
    entry = @year.breaks.find_by!(name: "Spring break")
    assert_equal "added", entry.source
    patch planner_school_year_break_path(entry), params: {break: {school_year_id: school_years(:one).id, source: "repeating", name: "Updated"}}
    assert_equal @year, entry.reload.school_year
    assert_equal "added", entry.source
  end

  test "invalid names dates year bounds and overlaps retain entered values" do
    [{name: ""}, {starts_on: ""}, {ends_on: ""}, {ends_on: "2027-08-01"},
      {starts_on: "2026-10-20", ends_on: "2026-10-20"}].each do |invalid|
      assert_no_difference("Break.count") do
        post planner_school_year_breaks_path, params: {break: valid_attributes.merge(invalid)}
      end
      assert_response :unprocessable_content
      assert_select "turbo-frame#modal-lazy-content form input[name='break[name]']"
      assert_select ".text-red-600"
    end
  end

  test "started entries reject moving their start and deleting" do
    travel_to Time.utc(2026, 10, 20, 12) do
      patch planner_school_year_break_path(@entry), params: {break: {starts_on: "2026-10-21", ends_on: "2026-10-21"}}
      assert_response :unprocessable_content
      assert_equal Date.new(2026, 10, 20), @entry.reload.starts_on
      assert_no_difference("Break.count") { delete planner_school_year_break_path(@entry) }
      assert_response :unprocessable_content
    end
  end

  test "ended years reject adding or changing time off" do
    travel_to Time.utc(2027, 6, 1, 12) do
      get new_planner_school_year_break_path
      assert_response :forbidden
      post planner_school_year_breaks_path, params: {break: valid_attributes}
      assert_response :unprocessable_content
      patch planner_school_year_break_path(@entry), params: {break: {name: "Changed"}}
      assert_response :unprocessable_content
    end
  end

  private

  def valid_attributes
    {name: "Spring break", starts_on: "2027-03-15", ends_on: "2027-03-19"}
  end
end
