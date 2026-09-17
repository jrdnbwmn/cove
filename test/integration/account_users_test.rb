require "test_helper"

class Jumpstart::AccountUsersTest < ActionDispatch::IntegrationTest
  test "owner removing the other parent gives them a fresh family" do
    account = accounts(:company)
    sign_in users(:one)

    delete account_account_user_path(account, account_users(:company_regular_user))

    assert_redirected_to account
    assert_equal [users(:one)], account.reload.users.to_a
    assert_equal users(:two), users(:two).family.owner
  end

  test "a non-owner cannot remove the family owner" do
    sign_in users(:two)

    delete account_account_user_path(accounts(:company), account_users(:company_admin))

    assert_equal account_users(:company_admin), AccountUser.find(account_users(:company_admin).id)
  end
end
