require "test_helper"

class PerformanceIndexesTest < ActiveSupport::TestCase
  test "the webhook, charge, and OAuth lookups are indexed" do
    connection = ActiveRecord::Base.connection

    assert connection.index_exists?(:loops_webhook_events, :created_at)
    assert connection.index_exists?(:loops_webhook_events, :created_at, name: "index_loops_webhook_events_on_unprocessed_created_at")
    assert connection.index_exists?(:pay_charges, :subscription_id)
    assert connection.index_exists?(:connected_accounts, [:provider, :uid])
  end
end
