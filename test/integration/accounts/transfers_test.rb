require "test_helper"

class Jumpstart::AccountsTransferTest < ActionDispatch::IntegrationTest
  test "a signed-out visitor trying to transfer a family is sent to sign in" do
    patch account_transfer_path(accounts(:company)), params: {user_id: users(:two).id}

    assert_redirected_to new_user_session_path
  end

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
