require "test_helper"

class SchoolYearTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 8, 1, 12)
    @year = school_years(:one)
  end

  test "each family can find its own active year" do
    assert_equal @year, accounts(:one).school_year
    assert_equal school_years(:company), accounts(:company).school_year
    assert_not_equal @year, accounts(:company).school_year
    assert_not @year.dup.valid?
  end

  test "years require family ownership dates and active status" do
    [:account, :starts_on, :ends_on, :status].each do |attribute|
      year = @year.dup
      year[attribute] = nil unless attribute == :account
      year.account = nil if attribute == :account
      assert_not year.valid?
      assert_not_empty year.errors[attribute]
    end
    @year.status = "ended"
    assert_not @year.valid?
    assert_not_empty @year.errors[:status]
  end

  test "a year ends after it starts and is at most twelve months long" do
    [@year.starts_on, @year.starts_on - 1].each do |date|
      @year.ends_on = date
      assert_not @year.valid?
      assert_includes @year.errors[:ends_on], "End the year after it starts."
    end
    [[Date.new(2027, 3, 1), Date.new(2028, 3, 1)],
      [Date.new(2028, 2, 29), Date.new(2029, 2, 28)]].each do |starts_on, anniversary|
      @year.assign_attributes(starts_on: starts_on, ends_on: anniversary)
      assert @year.valid?
      @year.ends_on = anniversary + 1
      assert_not @year.valid?
      assert_includes @year.errors[:ends_on], "The year can be up to 12 months."
    end
  end

  test "school weekdays must include at least one valid day" do
    [nil, [], [-1], [7], [1, 7], [nil]].each do |days|
      @year.school_weekdays = days
      assert_not @year.valid?, days.inspect
      assert_not_empty @year.errors[:school_weekdays]
    end
    @year.school_weekdays = (0..6).to_a
    assert @year.valid?
  end

  test "deleting a family deletes its school years" do
    assert_difference "SchoolYear.count", -1 do
      accounts(:one).destroy!
    end
  end

  test "dates and weekdays can change before the year begins without history" do
    assert @year.update(starts_on: "2026-08-18", ends_on: "2027-05-27", school_weekdays: [1, 2, 3, 4])
    assert_empty @year.reload.weekday_history
  end

  test "a first year can start earlier after beginning but cannot start later" do
    travel_to Time.utc(2026, 10, 17, 12) do
      assert @year.update(starts_on: "2026-08-10")
      assert_not @year.update(starts_on: "2026-08-11")
      assert_not_empty @year.errors[:starts_on]
    end
  end

  test "later years cannot change their start after beginning" do
    @year.update!(tracked_from: nil)
    travel_to Time.utc(2026, 10, 17, 12) do
      assert_not @year.update(starts_on: "2026-08-10")
      assert_not_empty @year.errors[:starts_on]
    end
  end

  test "an end cannot precede today or existing time off" do
    travel_to Time.utc(2027, 1, 5, 12) do
      assert_not @year.update(ends_on: "2027-01-04")
      assert_includes @year.errors[:ends_on], "The end can't be before today."
    end
    assert_not @year.update(ends_on: "2026-12-25")
    assert_includes @year.errors[:ends_on], "Winter break ends after this date. Change it first."
  end

  test "ended years cannot be edited or extended" do
    travel_to Time.utc(2027, 6, 1, 12) do
      assert_not @year.update(ends_on: "2027-06-02")
      @year.reload
      assert_not @year.update(school_weekdays: [1, 2, 3, 4])
      assert_not_empty @year.errors[:base]
    end
  end

  test "weekday changes keep yesterday's setting and same-day changes keep the original past" do
    travel_to Time.utc(2026, 10, 17, 12) do
      assert @year.update(school_weekdays: [1, 2, 3, 4])
      assert_equal [{"through" => "2026-10-16", "days" => [1, 2, 3, 4, 5]}], @year.reload.weekday_history
      assert @year.update(school_weekdays: [1, 3, 5])
      assert_equal [{"through" => "2026-10-16", "days" => [1, 2, 3, 4, 5]}], @year.reload.weekday_history
    end
    travel_to Time.utc(2026, 10, 18, 12) do
      assert @year.update(school_weekdays: [1, 2])
      assert_equal({"through" => "2026-10-17", "days" => [1, 3, 5]}, @year.reload.weekday_history.last)
    end
  end

  test "invalid saves and validation retries do not accumulate weekday history" do
    travel_to Time.utc(2026, 10, 17, 12) do
      @year.assign_attributes(school_weekdays: [1, 2], ends_on: nil)
      assert_not @year.save
      assert_empty @year.weekday_history
      @year.ends_on = Date.new(2027, 5, 28)
      2.times { assert @year.valid? }
      assert_empty @year.weekday_history
      assert @year.save
      assert_equal 1, @year.reload.weekday_history.size
    end
  end

  test "a weekday change on the first day has no historical days" do
    travel_to Time.utc(2026, 8, 17, 12) do
      assert @year.update(school_weekdays: [1, 2])
      assert_empty @year.reload.weekday_history
    end
  end

  test "a year can end up to twelve months after it starts" do
    assert_equal Date.new(2027, 8, 17), @year.tap { |year| year.starts_on = Date.new(2026, 8, 17) }.max_ends_on
  end
end
