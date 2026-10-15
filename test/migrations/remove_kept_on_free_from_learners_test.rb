require "test_helper"

class RemoveKeptOnFreeFromLearnersTest < ActiveSupport::TestCase
  test "learners no longer store a Free selection" do
    assert_not ActiveRecord::Base.connection.column_exists?(:learners, :kept_on_free)
  end

  test "rollback restores the boolean flag with its default and null constraint" do
    require Rails.root.glob("db/migrate/*_remove_kept_on_free_from_learners.rb").first.to_s
    migration = RemoveKeptOnFreeFromLearners.new
    migration.migrate(:down)
    column = ActiveRecord::Base.connection.columns(:learners).find { |entry| entry.name == "kept_on_free" }
    assert_equal :boolean, column.type
    assert_equal "false", column.default.to_s
    assert_not_predicate column, :null
    migration.migrate(:up)
    assert_not ActiveRecord::Base.connection.column_exists?(:learners, :kept_on_free)
  ensure
    migration&.migrate(:up) if ActiveRecord::Base.connection.column_exists?(:learners, :kept_on_free)
    Learner.reset_column_information
  end
end
