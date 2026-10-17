require "test_helper"

class SchoolYear::DefaultsTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(owner: users(:admin), name: "Default family")
  end

  test "shared calendar defaults expose the August start May end and winter across years" do
    assert_equal Date.new(2026, 8, 17), SchoolYear.default_starts_on(2026)
    assert_equal Date.new(2027, 5, 28), SchoolYear.default_ends_on(2026)
    assert_equal [
      ["Thanksgiving", Date.new(2026, 11, 26), Date.new(2026, 11, 27)],
      ["Winter holidays", Date.new(2026, 12, 21), Date.new(2027, 1, 1)]
    ], SchoolYear.default_breaks_for(2026)
    assert_equal Date.new(2028, 1, 1), SchoolYear.default_breaks_for(2027).last.last
  end

  test "upcoming default years have calculated school days and the two supplied holidays" do
    [[2026, "2026-08-17", "2027-05-28", 193],
      [2027, "2027-08-16", "2028-05-26", 194],
      [2028, "2028-08-21", "2029-05-25", 190]].each do |year, start_date, end_date, total|
      travel_to Time.utc(year, 7, 10, 12) do
        school_year = SchoolYear.create_default_for!(@account)
        assert_equal Date.iso8601(start_date), school_year.starts_on
        assert_equal Date.iso8601(end_date), school_year.ends_on
        assert_equal [1, 2, 3, 4, 5], school_year.school_weekdays
        assert_equal total, school_year.school_days_count
        assert_equal school_year.starts_on, school_year.tracked_from
        assert_equal ["Thanksgiving", "Winter holidays"], school_year.breaks.ordered.pluck(:name)
        assert_equal ["default"], school_year.breaks.distinct.pluck(:source)
        school_year.destroy!
      end
    end
  end

  test "January signup uses the year that began the previous calendar year" do
    travel_to Time.utc(2027, 1, 12, 12) do
      year = SchoolYear.create_default_for!(@account)
      assert_equal Date.new(2027, 1, 12), year.starts_on
      assert_equal Date.new(2027, 5, 28), year.ends_on
      assert_empty year.breaks
      assert_equal year.starts_on, year.tracked_from
    end
  end

  test "summer before-start and last-day signups get the upcoming year" do
    [Date.new(2027, 5, 28), Date.new(2027, 7, 10), Date.new(2027, 8, 15)].each do |date|
      travel_to Time.utc(date.year, date.month, date.day, 12) do
        year = SchoolYear.create_default_for!(@account)
        assert_equal Date.new(2027, 8, 16), year.starts_on
        assert_equal Date.new(2028, 5, 26), year.ends_on
        assert_equal 2, year.breaks.count
        year.destroy!
      end
    end
  end

  test "a signup on the default start keeps that year" do
    travel_to Time.utc(2026, 8, 17, 12) do
      year = SchoolYear.create_default_for!(@account)
      assert_equal Date.new(2026, 8, 17), year.starts_on
      assert_equal Date.new(2027, 5, 28), year.ends_on
      assert_equal year.starts_on, year.tracked_from
    end
  end

  test "weekend signup starts today and tracks from the next school day" do
    travel_to Time.utc(2026, 10, 17, 12) do
      year = SchoolYear.create_default_for!(@account)
      assert_equal Date.new(2026, 10, 17), year.starts_on
      assert_equal Date.new(2026, 10, 19), year.tracked_from
    end
  end

  test "Thanksgiving signup starts its time off today and tracks from Monday" do
    travel_to Time.utc(2026, 11, 27, 12) do
      year = SchoolYear.create_default_for!(@account)
      entry = year.breaks.ordered.first
      assert_equal Date.new(2026, 11, 27), entry.starts_on
      assert_equal Date.new(2026, 11, 27), entry.ends_on
      assert_equal Date.new(2026, 11, 30), year.tracked_from
    end
  end

  test "winter signup keeps only the remainder of the break" do
    travel_to Time.utc(2026, 12, 26, 12) do
      year = SchoolYear.create_default_for!(@account)
      entry = year.breaks.sole
      assert_equal "Winter holidays", entry.name
      assert_equal Date.new(2026, 12, 26), entry.starts_on
      assert_equal Date.new(2027, 1, 1), entry.ends_on
      assert_equal Date.new(2027, 1, 4), year.tracked_from
    end
  end
end
