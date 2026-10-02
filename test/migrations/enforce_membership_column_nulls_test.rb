require "test_helper"

class EnforceMembershipColumnNullsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "membership foreign keys and counter cache cannot be null" do
    connection = ActiveRecord::Base.connection

    assert_not_predicate connection.columns(:accounts).find { |column| column.name == "account_users_count" }, :null
    assert_not_predicate connection.columns(:account_users).find { |column| column.name == "account_id" }, :null
    assert_not_predicate connection.columns(:account_users).find { |column| column.name == "user_id" }, :null
  end
end
