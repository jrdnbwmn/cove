require "test_helper"

class Jumpstart::AccountsAccountInvitationsTest < ActionDispatch::IntegrationTest
  test "a full family cannot create another invitation" do
    sign_in users(:one)

    assert_no_difference "AccountInvitation.count" do
      post account_account_invitations_path(accounts(:company)), params: {account_invitation: {name: "Third Parent", email: "third@example.com"}}
    end

    assert_equal "Family already has two parents", flash[:alert]
  end

  test "a one-parent family creates an admin invitation" do
    account = accounts(:one)
    sign_in users(:noaccount)

    assert_difference "AccountInvitation.count", 1 do
      post account_account_invitations_path(account), params: {account_invitation: {name: "Second Parent", email: "second-parent@example.com", admin: "0"}}
    end

    assert_predicate account.account_invitations.last, :admin?
  end

  test "a family with a pending invitation cannot create a second one" do
    sign_in users(:user_without_billing_address)

    assert_no_difference "AccountInvitation.count" do
      post account_account_invitations_path(accounts(:invited)), params: {account_invitation: {name: "Second Parent", email: "second-parent@example.com"}}
    end

    assert_equal "Family already has two parents", flash[:alert]
  end
end
