require "test_helper"

class PerSeatSubscriptionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fake_processor)
    assert_equal 1, @account.account_users_count
    @account.payment_processor.subscribe(plan: "per_seat", quantity: @account.account_users_count)
  end

  test "adding a second parent leaves the subscription quantity unchanged" do
    @account.account_users.create!(user: users(:admin), admin: true)
    assert_equal 1, @account.payment_processor.subscription.quantity
  end

  test "removing a parent leaves the subscription quantity unchanged" do
    @account.account_users.last.destroy
    assert_equal 1, @account.payment_processor.subscription.quantity
  end
end
