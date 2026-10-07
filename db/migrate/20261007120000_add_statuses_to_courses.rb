class AddStatusesToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :completed_at, :datetime
    add_column :courses, :archived_at, :datetime
    add_check_constraint :courses, "completed_at IS NULL OR archived_at IS NULL", name: "courses_not_completed_and_archived"
  end
end
