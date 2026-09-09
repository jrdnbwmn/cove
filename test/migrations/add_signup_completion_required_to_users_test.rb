require "test_helper"

class AddSignupCompletionRequiredToUsersTest < ActiveSupport::TestCase
  test "users default to a completed signup state" do
    column = User.columns_hash.fetch("signup_completion_required")

    assert_equal :boolean, column.type
    assert_not_predicate column, :null
    assert_equal false, column.default
    assert_not_predicate users(:one), :signup_completion_required?
  end
end
