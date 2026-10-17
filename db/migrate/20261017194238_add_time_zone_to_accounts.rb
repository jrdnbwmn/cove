class AddTimeZoneToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :time_zone, :string, null: false, default: "Mountain Time (US & Canada)"
  end
end
