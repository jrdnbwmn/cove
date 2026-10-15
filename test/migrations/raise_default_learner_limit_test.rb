require "test_helper"

class RaiseDefaultLearnerLimitTest < ActiveSupport::TestCase
  test "families default to fifteen learners" do
    assert_equal 15, Account.default_learner_limit
  end

  test "existing family caps are only raised and rollback retains them" do
    connection = ActiveRecord::Base.connection
    migration = migration_class.new
    families = [accounts(:one), accounts(:two), accounts(:company)]
    [2, 15, 20].zip(families).each do |limit, family|
      connection.execute("UPDATE accounts SET learner_limit = #{limit} WHERE id = #{family.id}")
    end

    migration.migrate(:up)
    assert_equal [15, 15, 20], families.map { |family| family.reload.learner_limit }
    assert_equal "15", connection.columns(:accounts).find { |column| column.name == "learner_limit" }.default.to_s

    migration.migrate(:down)
    assert_equal [15, 15, 20], families.map { |family| family.reload.learner_limit }
    assert_equal "10", connection.columns(:accounts).find { |column| column.name == "learner_limit" }.default.to_s
  ensure
    migration&.migrate(:up)
    Account.reset_column_information
  end

  private

  def migration_class
    require Rails.root.glob("db/migrate/*_raise_default_learner_limit.rb").first.to_s
    RaiseDefaultLearnerLimit
  end
end
