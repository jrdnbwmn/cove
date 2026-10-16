require "test_helper"
require Rails.root.glob("db/migrate/*_enforce_learner_grade_levels.rb").first.to_s

class EnforceLearnerGradeLevelsTest < ActiveSupport::TestCase
  class LearnerRow < ApplicationRecord
    self.table_name = "learners"
  end

  test "the database accepts canonical grades and NULL but refuses free text" do
    learner = LearnerRow.find(learners(:one).id)
    ["Pre-K", "Kindergarten", "1st grade", "2nd grade", "3rd grade", "4th grade", "5th grade", "6th grade", "7th grade", "8th grade", "9th grade", "10th grade", "11th grade", "12th grade", nil].each do |grade|
      assert learner.update_columns(grade_level: grade)
    end
    ["", " ", "3rd", "Grade 3", "kindergarten", "unknown"].each do |grade|
      assert_raises(ActiveRecord::StatementInvalid) do
        Learner.transaction(requires_new: true) { learner.update_columns(grade_level: grade) }
      end
    end
  end

  test "rolling back the check allows legacy data and reapplying enforces it again" do
    migration = EnforceLearnerGradeLevels.new
    migration.migrate(:down)
    assert learners(:one).update_columns(grade_level: "3rd")
    learners(:one).update_columns(grade_level: "3rd grade")
    migration.migrate(:up)
    assert ActiveRecord::Base.connection.check_constraint_exists?(:learners, name: "learners_grade_level_is_canonical")
  ensure
    migration&.migrate(:up) unless ActiveRecord::Base.connection.check_constraint_exists?(:learners, name: "learners_grade_level_is_canonical")
  end
end
