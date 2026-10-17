require "test_helper"

class SchoolYear::CountingTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 8, 1, 12)
    @year = school_years(:one)
    @year.breaks.delete_all
    @year.assign_attributes(starts_on: Date.new(2026, 8, 17), ends_on: Date.new(2026, 8, 28))
  end

  test "school days include both boundaries and exclude weekends and dates outside the year" do
    assert @year.school_day?(Date.new(2026, 8, 17))
    assert @year.school_day?(Date.new(2026, 8, 28))
    [Date.new(2026, 8, 16), Date.new(2026, 8, 22), Date.new(2026, 8, 29)].each do |date|
      assert_not @year.school_day?(date)
    end
    assert_equal 10, @year.school_days_count
  end

  test "time off excludes both boundaries without subtracting weekends twice" do
    @year.save!
    @year.breaks.create!(name: "Time off", starts_on: "2026-08-21", ends_on: "2026-08-24")
    assert_not @year.school_day?(Date.new(2026, 8, 21))
    assert_not @year.school_day?(Date.new(2026, 8, 24))
    assert_equal 8, @year.school_days_count
  end

  test "leap day follows the selected school weekdays" do
    @year.assign_attributes(starts_on: Date.new(2028, 2, 28), ends_on: Date.new(2028, 3, 1))
    assert @year.school_day?(Date.new(2028, 2, 29))
    assert_equal 3, @year.school_days_count
  end

  test "today belongs to days to go and the two counts sum to the total" do
    travel_to Time.utc(2026, 8, 24, 12) do
      assert_equal 5, @year.so_far_count
      assert_equal 5, @year.to_go_count
      assert_equal @year.school_days_count, @year.so_far_count + @year.to_go_count
    end
  end

  test "the family day rather than the UTC date determines days so far" do
    @year.account.update!(time_zone: "Mountain Time (US & Canada)")
    travel_to Time.utc(2026, 8, 25, 6, 30) do
      assert_equal Date.new(2026, 8, 24), @year.account.today
      assert_equal 5, @year.so_far_count
      assert_equal 5, @year.to_go_count
    end
  end

  test "counts stay within the year before it starts and after it ends" do
    assert_equal 0, @year.so_far_count
    assert_equal 10, @year.to_go_count
    travel_to Time.utc(2026, 8, 29, 12) do
      assert_equal 10, @year.so_far_count
      assert_equal 0, @year.to_go_count
    end
  end

  test "before Cove days exclude the first tracked day and are included in days so far" do
    @year.tracked_from = Date.new(2026, 8, 24)
    travel_to Time.utc(2026, 8, 26, 12) do
      assert_equal 5, @year.before_cove_count
      assert_equal 7, @year.so_far_count
    end
    @year.tracked_from = nil
    assert_equal 0, @year.before_cove_count
  end

  test "weekday changes preserve earlier school days and use each historical setting" do
    @year.save!
    travel_to Time.utc(2026, 8, 24, 12) do
      assert_equal 5, @year.so_far_count
      @year.update!(school_weekdays: [1, 3])
      assert_equal 5, @year.so_far_count
      assert_equal 2, @year.to_go_count
    end
    travel_to Time.utc(2026, 8, 26, 12) do
      @year.update!(school_weekdays: [5])
      assert @year.school_day?(Date.new(2026, 8, 21))
      assert @year.school_day?(Date.new(2026, 8, 24))
      assert_not @year.school_day?(Date.new(2026, 8, 25))
      assert_not @year.school_day?(Date.new(2026, 8, 26))
      assert @year.school_day?(Date.new(2026, 8, 28))
      assert_equal 6, @year.so_far_count
      assert_equal 1, @year.to_go_count
      assert_equal 7, @year.school_days_count
      assert_equal @year.school_days_count, @year.so_far_count + @year.to_go_count
    end
  end

  test "extension previews count only added school days without changing the year" do
    assert_equal 0, @year.added_days_if_ended_on(@year.ends_on - 1)
    assert_equal 0, @year.added_days_if_ended_on(@year.ends_on)
    assert_equal 0, @year.added_days_if_ended_on(Date.new(2026, 8, 30))
    assert_equal 2, @year.added_days_if_ended_on(Date.new(2026, 9, 1))
    assert_nil @year.added_days_if_ended_on(@year.max_ends_on + 1)
    assert_equal Date.new(2026, 8, 28), @year.ends_on
    @year.school_weekdays = [2]
    assert_equal 1, @year.added_days_if_ended_on(Date.new(2026, 9, 1))
  end

  test "counting loads time off once rather than querying for each school day" do
    @year.account
    @year.breaks.reset
    assert_queries_count(1) { assert_equal 10, @year.school_days_count }
  end

  test "time off can cover every remaining school day" do
    @year.save!
    @year.breaks.create!(name: "Family leave", starts_on: "2026-08-24", ends_on: "2026-08-28")
    travel_to Time.utc(2026, 8, 24, 12) do
      assert_equal 5, @year.so_far_count
      assert_equal 0, @year.to_go_count
      assert_equal 5, @year.school_days_count
    end
  end
end
