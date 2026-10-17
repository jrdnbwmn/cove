require "test_helper"

class BackfillSchoolYearsTest < ActiveSupport::TestCase
  test "backfill provisions only active families without a year and can run again safely" do
    travel_to Time.utc(2026, 7, 10, 12) do
      family = Account.create!(owner: users(:admin), name: "Existing family")
      archived = Account.create!(owner: users(:marketing_subscribed), name: "Archived family", archived_at: Time.current)
      existing = accounts(:one).school_year
      migration = migration_class.new

      assert_difference({"SchoolYear.count" => 1, "Break.count" => 2}) { migration.migrate(:up) }
      year = family.school_year
      assert_equal "Mountain Time (US & Canada)", family.time_zone
      assert_equal Date.new(2026, 8, 17), year.starts_on
      assert_nil archived.school_year
      assert_equal existing, accounts(:one).school_year
      assert_no_difference ["SchoolYear.count", "Break.count"] do
        migration.migrate(:up)
        migration.migrate(:down)
      end
      assert_equal year, family.school_year
    end
  end

  private

  def migration_class
    require Rails.root.glob("db/migrate/*_backfill_school_years.rb").first.to_s
    BackfillSchoolYears
  end
end
