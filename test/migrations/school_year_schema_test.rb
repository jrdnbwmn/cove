require "test_helper"

class SchoolYearSchemaTest < ActiveSupport::TestCase
  test "families have a required Mountain time zone by default" do
    column = Account.columns_hash.fetch("time_zone")
    assert_equal :string, column.type
    assert_not column.null
    assert_equal "Mountain Time (US & Canada)", column.default
  end

  test "school years store dates weekdays history and an optional start time" do
    columns = connection.columns(:school_years).index_by(&:name)
    {account_id: :integer, starts_on: :date, ends_on: :date, school_weekdays: :integer,
     weekday_history: :jsonb, status: :string}.each do |name, type|
      assert_equal type, columns.fetch(name.to_s).type
      assert_not columns.fetch(name.to_s).null
    end
    assert columns.fetch("school_weekdays").array
    assert_equal "[]", columns.fetch("weekday_history").default
    assert_equal "active", columns.fetch("status").default
    assert_equal :date, columns.fetch("tracked_from").type
    assert columns.fetch("tracked_from").null
    assert_equal :time, columns.fetch("school_starts_at").type
    assert columns.fetch("school_starts_at").null
    assert connection.foreign_key_exists?(:school_years, :accounts)
    assert connection.index_exists?(:school_years, :account_id)
    index = connection.indexes(:school_years).find(&:unique)
    assert_equal ["account_id"], index.columns
    assert_match(/status.*active/, index.where)
    assert_check :school_years, "school_years_dates_ordered", "ends_on > starts_on"
  end

  test "time off has required indexed ownership and checked dates and sources" do
    columns = connection.columns(:breaks).index_by(&:name)
    {school_year_id: :integer, name: :string, starts_on: :date, ends_on: :date, source: :string}.each do |name, type|
      assert_equal type, columns.fetch(name.to_s).type
      assert_not columns.fetch(name.to_s).null
    end
    assert_equal "added", columns.fetch("source").default
    assert connection.foreign_key_exists?(:breaks, :school_years)
    assert connection.index_exists?(:breaks, :school_year_id)
    assert_check :breaks, "breaks_dates_ordered", "ends_on >= starts_on"
    source_check = connection.check_constraints(:breaks).find { |check| check.name == "breaks_source_allowed" }
    assert source_check
    %w[default added repeating].each { |source| assert_includes source_check.expression, source }
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def assert_check(table, name, expression)
    check = connection.check_constraints(table).find { |constraint| constraint.name == name }
    assert check
    assert_equal expression, check.expression.delete("()")
  end
end
