require "test_helper"

class Jumpstart::AccountsTransferTest < ActionDispatch::IntegrationTest
  test "owner can transfer the family to the other parent" do
    account = accounts(:company)
    sign_in users(:one)

    patch account_transfer_path(account), params: {user_id: users(:two).id}

    assert_equal users(:two), account.reload.owner
  end

  test "second parent cannot transfer ownership" do
    sign_in users(:two)

    patch account_transfer_path(accounts(:company)), params: {user_id: users(:two).id}

    assert_not_equal users(:two), accounts(:company).reload.owner
  end
end
