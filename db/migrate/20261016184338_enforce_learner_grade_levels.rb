class EnforceLearnerGradeLevels < ActiveRecord::Migration[8.1]
  GRADE_LEVELS = ["Pre-K", "Kindergarten", "1st grade", "2nd grade", "3rd grade", "4th grade", "5th grade", "6th grade", "7th grade", "8th grade", "9th grade", "10th grade", "11th grade", "12th grade"].freeze

  def change
    labels = GRADE_LEVELS.map { |label| connection.quote(label) }.join(", ")
    add_check_constraint :learners, "grade_level IS NULL OR grade_level IN (#{labels})", name: "learners_grade_level_is_canonical"
  end
end
