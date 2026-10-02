require "test_helper"

class AccountDeletionHelperTest < ActionView::TestCase
  include AccountDeletionHelper

  test "paid family deletion warns that Premium ends with no refund" do
    description = family_deletion_description(accounts(:subscribed))

    assert_includes description, "no refund is issued"
    assert_includes description, 'href="/refunds"'
  end

  test "free and complimentary family deletion only warns about data removal" do
    assert_equal I18n.t("accounts.deletion.free_description"), family_deletion_description(accounts(:one))
    assert_equal I18n.t("accounts.deletion.free_description"), family_deletion_description(accounts(:complimentary))
  end

  test "owner of a free family sees the plain login deletion copy" do
    assert_equal "cancel_my_account", login_deletion_copy_key(accounts(:one).owner)
  end

  test "owner of a paid family sees the Premium login deletion copy" do
    assert_equal "cancel_my_account_paid", login_deletion_copy_key(accounts(:subscribed).owner)
  end

  test "second parent sees the login deletion copy that leaves the family unchanged" do
    assert_equal "cancel_my_account_second_parent", login_deletion_copy_key(users(:two))
  end

  test "a past due family is told canceling ends the plan immediately" do
    subscription = pay_subscriptions(:past_due)

    assert cancels_immediately?(subscription)
    assert_equal I18n.t("billing.subscriptions.cancels.show.cancel_immediately"), cancellation_end_notice(subscription)
  end

  test "an unpaid family is told canceling ends the plan immediately" do
    subscription = pay_subscriptions(:unpaid)

    assert cancels_immediately?(subscription)
    assert_equal I18n.t("billing.subscriptions.cancels.show.cancel_immediately"), cancellation_end_notice(subscription)
  end

  test "an active family is told the plan ends at period end" do
    subscription = pay_subscriptions(:subscribed)

    assert_not cancels_immediately?(subscription)
    notice = cancellation_end_notice(subscription)

    assert_includes notice, "October 15, 2026"
    assert_includes notice, 'href="/refunds"'
  end

  test "an active family without a period end date is still told the plan ends at period end" do
    subscription = pay_subscriptions(:subscribed)
    subscription.current_period_end = nil

    notice = cancellation_end_notice(subscription)

    assert_includes notice, "end of your billing period"
    assert_includes notice, 'href="/refunds"'
  end
end
