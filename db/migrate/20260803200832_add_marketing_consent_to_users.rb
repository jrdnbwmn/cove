class AddMarketingConsentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :marketing_opt_in_at, :datetime
    add_column :users, :marketing_opt_in_source, :string
    add_column :users, :marketing_opt_out_at, :datetime
    add_column :users, :marketing_opt_out_reason, :string
  end
end
