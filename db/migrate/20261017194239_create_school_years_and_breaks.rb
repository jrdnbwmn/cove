class CreateSchoolYearsAndBreaks < ActiveRecord::Migration[8.1]
  def change
    create_table :school_years do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.integer :school_weekdays, array: true, null: false
      t.jsonb :weekday_history, null: false, default: []
      t.date :tracked_from
      t.string :status, null: false, default: "active"
      t.time :school_starts_at
      t.timestamps
    end
    add_index :school_years, :account_id, unique: true, where: "status = 'active'", name: "index_school_years_on_active_account"
    add_check_constraint :school_years, "ends_on > starts_on", name: "school_years_dates_ordered"

    create_table :breaks do |t|
      t.references :school_year, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :source, null: false, default: "added"
      t.timestamps
    end
    add_check_constraint :breaks, "ends_on >= starts_on", name: "breaks_dates_ordered"
    add_check_constraint :breaks, "source IN ('default', 'added', 'repeating')", name: "breaks_source_allowed"
  end
end
