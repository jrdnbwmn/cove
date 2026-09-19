class AddComplimentaryPremiumToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :complimentary_premium, :boolean, default: false, null: false
    add_column :accounts, :complimentary_premium_note, :string
  end
end
