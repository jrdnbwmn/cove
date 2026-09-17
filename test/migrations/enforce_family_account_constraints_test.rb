require "test_helper"

class EnforceFamilyAccountConstraintsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "families enforce the database membership and personal-account contracts" do
    connection = ActiveRecord::Base.connection
    personal = connection.columns(:accounts).find { |column| column.name == "personal" }

    assert_equal :boolean, personal.type
    assert_not_predicate personal, :null
    assert_equal false, personal.default
    assert connection.check_constraints(:accounts).any? { |constraint| constraint.name == "accounts_personal_must_be_false" }
    assert connection.indexes(:accounts).any? { |index| index.columns == ["archived_at"] }
    assert connection.indexes(:account_users).any? { |index| index.unique && index.columns == ["user_id"] }
  end
end
