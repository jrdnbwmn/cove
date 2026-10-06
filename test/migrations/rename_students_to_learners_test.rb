require "test_helper"

class RenameStudentsToLearnersTest < ActiveSupport::TestCase
  test "the learners table replaces the students table" do
    connection = ActiveRecord::Base.connection

    assert connection.table_exists?(:learners)
    assert_not connection.table_exists?(:students)
  end

  test "families default to a learner limit of ten" do
    column = Account.columns_hash.fetch("learner_limit")

    assert_equal :integer, column.type
    assert_not_predicate column, :null
    assert_equal 10, column.default
    assert_equal 10, accounts(:one).learner_limit
    assert_not Account.column_names.include?("student_limit")
  end

  test "learner indexes carry the new names, including the case-insensitive unique name index" do
    indexes = ActiveRecord::Base.connection.indexes(:learners).index_by(&:name)

    assert indexes.key?("index_learners_on_account_id")
    assert indexes.fetch("index_learners_on_account_id_and_lower_name").unique
    assert_equal ["index_learners_on_account_id", "index_learners_on_account_id_and_lower_name"], indexes.keys.sort
  end

  test "learners belong to a family through a foreign key" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:learners)

    assert_equal ["accounts"], foreign_keys.map(&:to_table)
  end
end
