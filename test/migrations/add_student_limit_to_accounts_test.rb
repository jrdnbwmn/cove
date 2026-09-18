require "test_helper"

class AddStudentLimitToAccountsTest < ActiveSupport::TestCase
  test "families default to a student limit of ten" do
    column = Account.columns_hash.fetch("student_limit")

    assert_equal :integer, column.type
    assert_not_predicate column, :null
    assert_equal 10, column.default
    assert_equal 10, accounts(:one).student_limit
  end
end
