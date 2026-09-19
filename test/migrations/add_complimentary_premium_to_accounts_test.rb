require "test_helper"

class AddComplimentaryPremiumToAccountsTest < ActiveSupport::TestCase
  test "families default to free Premium access with an optional note" do
    premium_column = Account.columns_hash.fetch("complimentary_premium")
    note_column = Account.columns_hash.fetch("complimentary_premium_note")

    assert_equal :boolean, premium_column.type
    assert_not_predicate premium_column, :null
    assert_equal false, premium_column.default
    assert_equal :string, note_column.type
    assert_predicate note_column, :null
  end
end
