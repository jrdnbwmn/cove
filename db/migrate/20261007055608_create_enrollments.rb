class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :course, null: false, foreign_key: true, index: false
      t.references :learner, null: false, foreign_key: true

      t.timestamps
    end

    add_index :enrollments, [:course_id, :learner_id], unique: true
  end
end
