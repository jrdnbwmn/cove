require "test_helper"

class SchoolYearsHelperTest < ActionView::TestCase
  include ApplicationHelper

  setup do
    travel_to Time.utc(2026, 8, 20, 12)
    @year = school_years(:company)
    @year.assign_attributes(starts_on: Date.new(2026, 8, 17), ends_on: Date.new(2026, 8, 28))
  end

  test "school weekdays show a range only when all days are consecutive" do
    assert_equal "Mon–Fri", school_weekdays_label([1, 2, 3, 4, 5])
    assert_equal "Mon–Thu", school_weekdays_label([4, 2, 1, 3])
    assert_equal "Mon, Wed, Fri", school_weekdays_label([1, 3, 5])
    assert_equal "Mon", school_weekdays_label([1])
    assert_equal "Sat–Sun", school_weekdays_label([0, 6])
    assert_equal "Mon–Sun", school_weekdays_label([0, 1, 2, 3, 4, 5, 6])
  end

  test "running year shows calculated days so far and still to go" do
    assert_equal "Mon–Fri · 17–28 Aug · 10 school days · 3 so far, 7 to go", school_year_summary(@year)
  end

  test "first year includes days before Cove when any exist" do
    @year.tracked_from = Date.new(2026, 8, 19)
    assert_equal "Mon–Fri · 17–28 Aug · 10 school days · 3 so far, 7 to go, including 2 before Cove", school_year_summary(@year)
    @year.tracked_from = nil
    assert_no_match(/before Cove/, school_year_summary(@year))
  end

  test "upcoming year shows its start date instead of elapsed days" do
    travel_to Time.utc(2026, 8, 1, 12) do
      assert_equal "Mon–Fri · 17–28 Aug · 10 school days · Starts 17 Aug", school_year_summary(@year)
    end
  end

  test "ended year keeps its total and explains that the year has ended" do
    travel_to Time.utc(2026, 8, 29, 12) do
      assert_equal "Mon–Fri · 17–28 Aug · 10 school days · This year has ended.", school_year_summary(@year)
    end
  end

  test "summary uses actual totals with time off and zero days remaining" do
    @year.breaks.build(name: "Time off", starts_on: Date.new(2026, 8, 20), ends_on: Date.new(2026, 8, 28), source: "custom")
    assert_equal "Mon–Fri · 17–28 Aug · 3 school days · 3 so far, 0 to go", school_year_summary(@year)
  end

  test "year date ranges keep both years when crossing calendar years" do
    assert_includes school_year_summary(school_years(:one)), "17 Aug 2026–28 May 2027"
  end

  test "school weekday options start on Monday and use wday values" do
    assert_equal [["Mon", 1], ["Tue", 2], ["Wed", 3], ["Thu", 4], ["Fri", 5], ["Sat", 6], ["Sun", 0]], school_weekday_options
  end

  test "the time off button says what it will do" do
    entry = Break.new
    assert_equal "Add time off", time_off_submit_label(entry, [], false)
    entry.stub(:persisted?, true) { assert_equal "Save", time_off_submit_label(entry, [], false) }
    assert_equal "Replace it", time_off_submit_label(entry, [Break.new], true)
    assert_equal "Replace them", time_off_submit_label(entry, [Break.new, Break.new], true)
  end
end
