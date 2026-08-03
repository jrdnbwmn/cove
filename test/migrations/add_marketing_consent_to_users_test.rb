require "test_helper"

class AddMarketingConsentToUsersTest < ActiveSupport::TestCase
  test "users retain nullable marketing consent fields without defaults" do
    expected_columns = {
      "marketing_opt_in_at" => :datetime,
      "marketing_opt_in_source" => :string,
      "marketing_opt_out_at" => :datetime,
      "marketing_opt_out_reason" => :string
    }

    expected_columns.each do |name, type|
      column = User.columns_hash.fetch(name)

      assert_equal type, column.type
      assert_predicate column, :null
      assert_nil column.default
    end

    user = users(:one)
    assert_nil user.marketing_opt_in_at
    assert_nil user.marketing_opt_in_source
    assert_nil user.marketing_opt_out_at
    assert_nil user.marketing_opt_out_reason
  end
end
