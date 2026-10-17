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
end
