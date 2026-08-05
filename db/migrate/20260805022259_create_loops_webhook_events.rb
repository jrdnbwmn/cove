class CreateLoopsWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :loops_webhook_events do |t|
      t.string :webhook_id, null: false
      t.string :event_name, null: false
      t.datetime :event_time
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :loops_webhook_events, :webhook_id, unique: true
  end
end
