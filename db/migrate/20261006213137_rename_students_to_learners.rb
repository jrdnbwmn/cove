class RenameStudentsToLearners < ActiveRecord::Migration[8.1]
  def change
    rename_table :students, :learners
    rename_column :accounts, :student_limit, :learner_limit

    # AIDEV-NOTE: rename_table only renames indexes that follow Rails' default
    # naming (index_students_on_account_id). This expression index has a custom
    # name, so it is renamed explicitly or it would keep "students" forever.
    rename_index :learners, "index_students_on_account_id_and_lower_name", "index_learners_on_account_id_and_lower_name"
  end
end
