require "test_helper"

class SchoolYears::ShapeOfDaysTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @year = school_years(:company)
    sign_in users(:one)
  end

  test "guests must sign in to view and save the start time" do
    sign_out users(:one)
    get edit_planner_school_year_shape_of_day_path
    assert_redirected_to new_user_session_path
    patch planner_school_year_shape_of_day_path, params: {school_year: {school_starts_at: "08:30"}}
    assert_redirected_to new_user_session_path
  end

  test "either parent can set change and clear their family's start time" do
    [users(:one), users(:two)].each do |parent|
      sign_in parent
      get edit_planner_school_year_shape_of_day_path
      assert_response :success
      assert_select "turbo-frame#modal-lazy-content form[action=?]", planner_school_year_shape_of_day_path
      assert_select "h2.font-sans", text: "Shape of the day"
      assert_select "label", text: "School usually starts at"
      assert_select "select#school_year_school_starts_at[name='school_year[school_starts_at]'][data-select-dropdown-input-value=true][data-select-allow-empty-option-value=true]" do
        assert_select "option", count: 70
        assert_select "option[value='']", text: "No usual start time"
        assert_select "option[value='08:30']", text: "8:30am"
      end
      assert_select "p", text: "Optional. Cove uses this to estimate times on your day."
      ["08:30", "09:45", "", "nonsense"].each do |value|
        patch planner_school_year_shape_of_day_path, params: {school_year: {school_starts_at: value}}
        assert_redirected_to planner_school_year_path
        assert_equal "Saved.", flash[:notice]
        if value.in?(["", "nonsense"])
          assert_nil @year.reload.school_starts_at
        else
          assert_equal value, @year.reload.school_starts_at.strftime("%H:%M")
        end
      end
      sign_out parent
    end
  end

  test "editing preserves saved usual off-grid and out-of-range times" do
    ["08:30", "09:47", "22:30"].each do |value|
      @year.update!(school_starts_at: value)
      get edit_planner_school_year_shape_of_day_path
      assert_response :success
      assert_select "select option[value=?][selected]", value, count: 1
    end
  end

  test "start time changes ignore ownership dates and weekdays" do
    original = @year.attributes.except("school_starts_at", "updated_at")
    other = school_years(:one)
    patch planner_school_year_shape_of_day_path, params: {id: other.id, school_year: {school_starts_at: "08:30", account_id: other.account_id, starts_on: "2026-01-01", ends_on: "2027-08-01", school_weekdays: [0], tracked_from: nil, status: "ended"}}
    assert_redirected_to planner_school_year_path
    assert_equal original, @year.reload.attributes.except("school_starts_at", "updated_at")
    assert_nil other.reload.school_starts_at
  end

  test "a family without a year cannot access another family's start time" do
    @year.destroy!
    get edit_planner_school_year_shape_of_day_path, params: {id: school_years(:one).id}
    assert_response :not_found
  end

  test "ended years refuse opening and saving including a modal opened before the year ended" do
    get edit_planner_school_year_shape_of_day_path
    assert_response :success
    travel_to Time.utc(2027, 6, 1, 12) do
      get edit_planner_school_year_shape_of_day_path
      assert_response :forbidden
      patch planner_school_year_shape_of_day_path, params: {school_year: {school_starts_at: "08:30"}}
      assert_response :forbidden
      assert_nil @year.reload.school_starts_at
    end
  end

  test "validation errors keep the start time modal and entered value" do
    @year.update_columns(school_weekdays: [])
    patch planner_school_year_shape_of_day_path, params: {school_year: {school_starts_at: "08:30"}}
    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content h2", text: "Shape of the day"
    assert_select "select option[value='08:30'][selected]"
    assert_select "p", text: "Choose at least one school day."
    assert_nil @year.reload.school_starts_at
  end
  test "both Planner tabs show the labeled action only while the year is editable" do
    [planner_path, planner_school_year_path].each do |path|
      get path
      assert_select "[data-page-header-actions] [data-ui-modal-turbo-frame-src-value=?] button", edit_planner_school_year_shape_of_day_path, text: "Shape of the day"
      travel_to Time.utc(2027, 6, 1, 12) do
        get path
        assert_select "[data-ui-modal-turbo-frame-src-value=?]", edit_planner_school_year_shape_of_day_path, count: 0
      end
    end
  end

  test "saves return to either originating tab with a complete layout and toast host" do
    [planner_path, planner_school_year_path].each do |path|
      patch planner_school_year_shape_of_day_path, params: {school_year: {school_starts_at: "08:30"}}, headers: {"Referer" => "http://www.example.com#{path}", "Turbo-Frame" => "modal-lazy-content"}
      assert_redirected_to path
      follow_redirect!
      assert_select "head link[data-turbo-track=reload]"
      assert_select "#toasts"
      assert_select "h1", text: "Planner"
    end
  end

  test "untrusted malformed and unrelated referrers fall back to School year" do
    [nil, "http://evil.test/planner", "https://www.example.com/planner", "http://www.example.com:81/planner", "http://www.example.com/learners", "http://[", "//www.example.com/planner"].each do |referrer|
      headers = referrer ? {"Referer" => referrer} : {}
      patch planner_school_year_shape_of_day_path, params: {school_year: {school_starts_at: "08:30"}}, headers: headers
      assert_redirected_to planner_school_year_path
    end
  end
end
