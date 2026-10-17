require "test_helper"

class BreakTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @year = school_years(:one)
    @break = @year.breaks.new(name: "Teacher day", starts_on: "2026-10-20", ends_on: "2026-10-20")
  end

  test "a family can add one day of time off" do
    assert @break.save
    assert_equal "added", @break.source
    assert_equal @year, @break.school_year
  end

  test "time off needs a name year and dates" do
    [:name, :school_year, :starts_on, :ends_on].each do |attribute|
      entry = @break.dup
      entry.public_send("#{attribute}=", nil)
      assert_not entry.valid?
      assert_not_empty entry.errors[attribute]
    end
  end

  test "time off stays inside the year and ends on or after its start" do
    [[@year.starts_on - 1, @year.starts_on], [@year.ends_on, @year.ends_on + 1],
      [Date.new(2026, 10, 22), Date.new(2026, 10, 21)]].each do |start_date, end_date|
      @break.assign_attributes(starts_on: start_date, ends_on: end_date)
      assert_not @break.valid?
    end
  end

  test "time off rejects inclusive overlaps but allows editing itself" do
    winter = breaks(:winter)
    [[winter.starts_on - 1, winter.starts_on], [winter.ends_on, winter.ends_on + 1],
      [winter.starts_on - 1, winter.ends_on + 1], [winter.starts_on + 1, winter.ends_on - 1]].each do |start_date, end_date|
      @break.assign_attributes(starts_on: start_date, ends_on: end_date)
      assert_not @break.valid?
      assert_includes @break.overlaps, winter
    end
    assert winter.update(name: "Winter holiday")
    @break.assign_attributes(starts_on: winter.ends_on + 1, ends_on: winter.ends_on + 1)
    assert @break.valid?
    @break.school_year = school_years(:company)
    @break.assign_attributes(starts_on: winter.starts_on, ends_on: winter.ends_on)
    assert @break.valid?
  end

  test "time off accepts only its three sources and is ordered by start" do
    %w[default added repeating].each do |source|
      @break.source = source
      assert @break.valid?
    end
    @break.source = "unknown"
    assert_not @break.valid?
    assert_equal [breaks(:thanksgiving), breaks(:winter)], @year.breaks.ordered.to_a
  end

  test "new time off cannot start before the family day" do
    @break.starts_on = @year.account.today - 1
    assert_not @break.valid?
    assert_includes @break.errors[:starts_on], "Choose a start date from today on."
    @break.starts_on = @year.account.today
    assert @break.valid?
  end

  test "future time off cannot be moved into the past" do
    entry = breaks(:thanksgiving)
    assert_not entry.update(starts_on: @year.account.today - 1)
    assert_includes entry.errors[:starts_on], "Choose a start date from today on."
  end

  test "started time off allows only name and end changes and cannot be deleted" do
    entry = breaks(:winter)
    travel_to Time.utc(2026, 12, 22, 12) do
      assert entry.update(name: "Winter holiday", ends_on: "2026-12-23")
      assert_not entry.update(starts_on: "2026-12-22")
      entry.reload
      assert_not entry.update(ends_on: "2026-12-21")
      entry.reload
      assert_not entry.update(source: "added")
      entry.reload
      assert_no_difference("Break.count") { assert_not entry.destroy }
    end
  end

  test "ended years reject time off creation editing and deletion" do
    travel_to Time.utc(2027, 6, 1, 12) do
      assert_not @break.save
      assert_not breaks(:winter).update(name: "Changed")
      assert_not breaks(:winter).destroy
    end
  end

  test "deleting a family removes even protected historical time off" do
    travel_to Time.utc(2027, 6, 1, 12) do
      assert_difference("Break.count", -2) { @year.account.destroy! }
    end
  end
end
