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

  test "invalid names dates and year bounds retain entered values" do
    [{name: ""}, {starts_on: ""}, {ends_on: ""}, {ends_on: "2027-08-01"}].each do |invalid|
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

  test "overlap warning lists the conflict and offers Replace it with entered values kept" do
    post planner_school_year_breaks_path, params: {break: overlap_attributes}
    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content" do
      assert_select "form#time-off-form input[name='break[name]'][value='Fall trip']"
      assert_select "form#time-off-form input[name='break[starts_on]'][value='2026-10-19']"
      assert_select "form#time-off-form input[name='break[replace]'][value='1']"
      assert_select "form#time-off-form button[type='submit']", text: /Replace it/
      assert_select "h3", text: "This overlaps Teacher day (20 Oct)."
      assert_select "button", text: "Cancel"
    end
    assert_select "form#time-off-form", text: /This overlaps other time off/, count: 0
  end

  test "overlap warning lists every conflict and says Replace them" do
    @year.breaks.create!(name: "Co-op day", starts_on: "2026-10-21", ends_on: "2026-10-21")
    post planner_school_year_breaks_path, params: {break: overlap_attributes}
    assert_response :unprocessable_content
    assert_select "h3", text: "This overlaps Teacher day (20 Oct) and Co-op day (21 Oct)."
    assert_select "form#time-off-form button[type='submit']", text: /Replace them/
  end

  test "Replace swaps future overlapping time off for the new entry" do
    post planner_school_year_breaks_path, params: {break: overlap_attributes.merge(replace: "1")}
    assert_redirected_to planner_school_year_path
    assert_not @year.breaks.exists?(id: @entry.id)
    assert_equal "added", @year.breaks.find_by!(name: "Fall trip").source
  end

  test "Replace can save an edited entry over a future overlap" do
    other = @year.breaks.create!(name: "Co-op day", starts_on: "2026-10-27", ends_on: "2026-10-27")
    patch planner_school_year_break_path(other), params: {break: {starts_on: "2026-10-20", ends_on: "2026-10-27", replace: "1"}}
    assert_redirected_to planner_school_year_path
    assert_not @year.breaks.exists?(id: @entry.id)
    assert_equal Date.new(2026, 10, 20), other.reload.starts_on
  end

  test "without Replace an overlap deletes nothing" do
    assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {break: overlap_attributes} }
    assert @year.breaks.exists?(id: @entry.id)
  end

  test "started overlaps block Replace, delete nothing, and link to Edit" do
    future = @year.breaks.create!(name: "Co-op day", starts_on: "2026-10-23", ends_on: "2026-10-23")
    travel_to Time.utc(2026, 10, 20, 12) do
      [{}, {replace: "1"}].each do |extra|
        assert_no_difference("Break.count") do
          post planner_school_year_breaks_path, params: {break: overlap_attributes.merge(starts_on: "2026-10-20", ends_on: "2026-10-23").merge(extra)}
        end
        assert_response :unprocessable_content
        assert_select "form#time-off-form input[name='break[replace]']", count: 0
        assert_select "form#time-off-form button", text: /Replace/, count: 0
        assert_select "turbo-frame#modal-lazy-content a[href='#{edit_planner_school_year_break_path(@entry)}']", text: /Teacher day/
        assert_select "a[href='#{edit_planner_school_year_break_path(future)}']", count: 0
      end
      assert @year.breaks.exists?(id: future.id)
    end
  end

  test "a conflict that starts after the warning was shown is not deleted" do
    post planner_school_year_breaks_path, params: {break: overlap_attributes}
    assert_select "input[name='break[replace]']"
    travel_to Time.utc(2026, 10, 20, 12) do
      assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {break: overlap_attributes.merge(replace: "1")} }
      assert_response :unprocessable_content
    end
    assert @year.breaks.exists?(id: @entry.id)
  end

  test "overlap names are escaped and submitted overlap ids are ignored" do
    @entry.update!(name: "<b>Bold</b> day")
    foreign = breaks(:winter)
    post planner_school_year_breaks_path, params: {break: overlap_attributes}
    assert_select "h3", text: "This overlaps <b>Bold</b> day (20 Oct)."
    assert_select "turbo-frame#modal-lazy-content b", count: 0
    post planner_school_year_breaks_path, params: {break: overlap_attributes.merge(replace: "1", overlap_ids: [foreign.id])}
    assert Break.exists?(foreign.id)
  end

  test "deleting time off removes it and offers a signed Undo" do
    entry = @year.breaks.create!(name: "Spring break", starts_on: "2027-03-15", ends_on: "2027-03-19", source: "default")
    assert_difference("Break.count", -1) { delete planner_school_year_break_path(entry) }
    assert_redirected_to planner_school_year_path
    toast = flash[:notice].with_indifferent_access
    assert_equal "Time off removed", toast[:title]
    assert_equal "Undo", toast[:action][:label]
    assert_equal planner_school_year_breaks_path, toast[:action][:url]
    assert toast[:action][:params][:restore].present?
  end

  test "Undo restores the deleted entry with its original source" do
    entry = @year.breaks.create!(name: "Spring break", starts_on: "2027-03-15", ends_on: "2027-03-19", source: "default")
    delete planner_school_year_break_path(entry)
    token = undo_token
    assert_difference("@year.breaks.count", 1) { post planner_school_year_breaks_path, params: {restore: token} }
    assert_redirected_to planner_school_year_path
    restored = @year.breaks.find_by!(name: "Spring break")
    assert_equal [Date.new(2027, 3, 15), Date.new(2027, 3, 19), "default"], [restored.starts_on, restored.ends_on, restored.source]
    assert_nil flash[:restore_error]
  end

  test "Undo explains an overlap that appeared after deletion and creates nothing" do
    entry = @year.breaks.create!(name: "Spring break", starts_on: "2027-03-15", ends_on: "2027-03-19", source: "added")
    delete planner_school_year_break_path(entry)
    token = undo_token
    @year.breaks.create!(name: "Teacher day", starts_on: "2027-03-17", ends_on: "2027-03-17")
    assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {restore: token} }
    assert_redirected_to planner_school_year_path
    assert_equal "We couldn't restore Spring break. It overlaps Teacher day.", flash[:restore_error]
  end

  test "Undo explains a start that has passed since deletion" do
    entry = @year.breaks.create!(name: "Spring break", starts_on: "2026-10-25", ends_on: "2026-10-26", source: "added")
    delete planner_school_year_break_path(entry)
    token = undo_token
    travel_to Time.utc(2026, 10, 26, 12) do
      assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {restore: token} }
      assert_equal "We couldn't restore Spring break. It would start in the past.", flash[:restore_error]
    end
  end

  test "submitting Undo twice restores once" do
    entry = @year.breaks.create!(name: "Spring break", starts_on: "2027-03-15", ends_on: "2027-03-19", source: "added")
    delete planner_school_year_break_path(entry)
    token = undo_token
    post planner_school_year_breaks_path, params: {restore: token}
    assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {restore: token} }
    assert_equal 1, @year.breaks.where(name: "Spring break").count
    assert_match(/We couldn't restore Spring break/, flash[:restore_error])
  end

  test "Undo payloads from another family or tampered with restore nothing" do
    foreign_token = breaks(:winter).restore_token
    [foreign_token, "#{foreign_token}x", "garbage"].each do |token|
      assert_no_difference("Break.count") { post planner_school_year_breaks_path, params: {restore: token} }
      assert_redirected_to planner_school_year_path
      assert_equal "We couldn't restore that time off.", flash[:restore_error]
    end
  end

  private

  def undo_token
    flash[:notice].with_indifferent_access.dig(:action, :params, :restore)
  end

  def overlap_attributes
    {name: "Fall trip", starts_on: "2026-10-19", ends_on: "2026-10-21"}
  end

  def valid_attributes
    {name: "Spring break", starts_on: "2027-03-15", ends_on: "2027-03-19"}
  end
end
