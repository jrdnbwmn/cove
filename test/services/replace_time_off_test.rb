require "test_helper"

class ReplaceTimeOffTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @year = school_years(:one)
  end

  test "a parent can save time off when the previous conflict no longer overlaps" do
    replacement = @year.breaks.new(name: "Teacher day", starts_on: "2026-10-20", ends_on: "2026-10-20")

    assert_difference "Break.count", 1 do
      assert_predicate ReplaceTimeOff.new(time_off: replacement).call, :success?
    end

    assert_equal "Teacher day", replacement.reload.name
  end

  test "a parent can replace one future entry with new time off" do
    previous = breaks(:winter)
    replacement = @year.breaks.new(name: "Winter holiday", starts_on: previous.starts_on, ends_on: previous.ends_on)

    assert_no_difference "Break.count" do
      result = ReplaceTimeOff.new(time_off: replacement).call
      assert_predicate result, :success?
      assert_equal replacement, result.time_off
    end

    assert_predicate replacement, :persisted?
    assert_not Break.exists?(previous.id)
    assert Break.exists?(breaks(:thanksgiving).id)
  end

  test "a parent can replace every overlapping future entry together" do
    previous_ids = @year.breaks.ids
    replacement = @year.breaks.new(name: "Long holiday", starts_on: "2026-11-26", ends_on: "2027-01-01")

    assert_difference "Break.count", -1 do
      assert_predicate ReplaceTimeOff.new(time_off: replacement).call, :success?
    end

    assert_empty Break.where(id: previous_ids)
    assert_equal [replacement], @year.breaks.reload.to_a
  end

  test "editing an entry replaces its future conflicts without deleting itself" do
    entry = breaks(:thanksgiving)
    original_id = entry.id
    replaced_id = breaks(:winter).id
    entry.assign_attributes(name: "Long holiday", ends_on: "2027-01-01")

    assert_difference "Break.count", -1 do
      assert_predicate ReplaceTimeOff.new(time_off: entry).call, :success?
    end

    assert_equal original_id, entry.reload.id
    assert_equal Date.new(2027, 1, 1), entry.ends_on
    assert_not Break.exists?(replaced_id)
  end

  test "editing an entry without another overlap keeps that entry" do
    entry = breaks(:winter)
    entry.name = "Winter holiday"

    assert_no_difference "Break.count" do
      assert_predicate ReplaceTimeOff.new(time_off: entry).call, :success?
    end

    assert_equal "Winter holiday", entry.reload.name
  end

  test "invalid new time off preserves all entries it would replace" do
    previous_ids = @year.breaks.ids
    replacement = @year.breaks.new(name: "", starts_on: "2026-11-26", ends_on: "2027-01-01")

    assert_no_difference "Break.count" do
      result = ReplaceTimeOff.new(time_off: replacement).call
      assert_not_predicate result, :success?
      assert_equal replacement, result.time_off
    end

    assert_equal previous_ids.sort, @year.breaks.reload.ids.sort
    assert_includes replacement.errors[:name], "Add a name."
    assert_predicate replacement, :new_record?
  end

  test "invalid edited time off preserves its saved values and overlapping entries" do
    entry = breaks(:thanksgiving)
    entry.assign_attributes(name: "", ends_on: "2027-01-01")

    assert_no_difference "Break.count" do
      assert_not_predicate ReplaceTimeOff.new(time_off: entry).call, :success?
    end

    assert Break.exists?(breaks(:winter).id)
    assert_equal "Thanksgiving", entry.reload.name
    assert_equal Date.new(2026, 11, 27), entry.ends_on
  end

  test "replacement checks conflicts added since the warning was shown" do
    replacement = @year.breaks.new(name: "Holiday", starts_on: "2026-11-26", ends_on: "2026-12-01")
    assert_equal [breaks(:thanksgiving)], replacement.overlaps.to_a
    newly_added = @year.breaks.create!(name: "Teacher day", starts_on: "2026-12-01", ends_on: "2026-12-01")

    assert_difference "Break.count", -1 do
      assert_predicate ReplaceTimeOff.new(time_off: replacement).call, :success?
    end

    assert_not Break.exists?(newly_added.id)
    assert_not Break.exists?(breaks(:thanksgiving).id)
  end

  test "a newly started conflict preserves both started and future overlaps" do
    replacement = @year.breaks.new(name: "Holiday", starts_on: "2026-11-26", ends_on: "2027-01-01")
    assert replacement.overlaps.none?(&:started?)

    travel_to Time.utc(2026, 11, 26, 12) do
      assert_no_difference "Break.count" do
        assert_not_predicate ReplaceTimeOff.new(time_off: replacement).call, :success?
      end
    end

    assert Break.exists?(breaks(:thanksgiving).id)
    assert Break.exists?(breaks(:winter).id)
    assert_predicate replacement, :new_record?
  end

  test "an ended year preserves all time off" do
    replacement = @year.breaks.new(name: "Holiday", starts_on: "2026-11-26", ends_on: "2027-01-01")

    travel_to Time.utc(2027, 6, 1, 12) do
      assert_no_difference "Break.count" do
        assert_not_predicate ReplaceTimeOff.new(time_off: replacement).call, :success?
      end
    end

    assert_equal 2, @year.breaks.count
  end
end
