class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :grade_level
      t.string :color, null: false
      t.datetime :archived_at

      t.timestamps
    end

    # AIDEV-NOTE: Expression index enforces case-insensitive name uniqueness per
    # family at the database level; the model validation gives friendly errors.
    add_index :students, "account_id, lower(name)", unique: true, name: "index_students_on_account_id_and_lower_name"
  end
end
