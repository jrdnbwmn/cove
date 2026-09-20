require "test_helper"

class AccountDeletionHelperTest < ActionView::TestCase
  include AccountDeletionHelper

  test "paid family deletion warns that Premium ends with no refund" do
    assert_equal I18n.t("accounts.deletion.paid_description"), family_deletion_description(accounts(:subscribed))
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
end
