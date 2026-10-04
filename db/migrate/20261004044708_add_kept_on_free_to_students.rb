class AddKeptOnFreeToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :kept_on_free, :boolean, default: false, null: false
  end
end
