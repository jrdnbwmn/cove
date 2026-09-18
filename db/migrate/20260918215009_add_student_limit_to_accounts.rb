class AddStudentLimitToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :student_limit, :integer, default: 10, null: false
  end
end
