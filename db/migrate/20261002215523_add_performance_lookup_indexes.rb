class AddPerformanceLookupIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :loops_webhook_events, :created_at, algorithm: :concurrently
    add_index :loops_webhook_events, :created_at,
      where: "processed_at IS NULL",
      name: "index_loops_webhook_events_on_unprocessed_created_at",
      algorithm: :concurrently
    add_index :pay_charges, :subscription_id, algorithm: :concurrently
    add_index :connected_accounts, [:provider, :uid], algorithm: :concurrently
  end
end
