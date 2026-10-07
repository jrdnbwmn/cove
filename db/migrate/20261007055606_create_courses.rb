class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :subject

      t.timestamps
    end
  end
end
