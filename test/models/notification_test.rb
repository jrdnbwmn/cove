require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "notifications retain their recorded invitation after a non-owner parent leaves" do
    user = users(:two)
    Account::AcceptedInviteNotifier.with(user: user, account: accounts(:company)).deliver(users(:one))

    assert_no_difference "Noticed::Notification.count" do
      user.destroy
    end
  end

  test "notifications with account are destroyed when account destroyed" do
    account = accounts(:one)
    Account::OwnershipNotifier.with(previous_owner: users(:one), account: account).deliver(users(:two))

    assert_difference "Noticed::Notification.count", -1 do
      account.destroy
    end
  end
end
