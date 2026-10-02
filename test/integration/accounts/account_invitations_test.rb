require "test_helper"

class Jumpstart::AccountsAccountInvitationsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

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

  test "a parent can invite someone who already has a Cove login" do
    account = accounts(:one)
    user = users(:twofactor)
    sign_in users(:noaccount)

    assert_difference "AccountInvitation.count", 1 do
      assert_enqueued_email_with AccountMailer, :invite, params: ->(params) { params[:account_invitation].email == user.email } do
        post account_account_invitations_path(account), params: {account_invitation: {name: user.name, email: user.email}}
      end
    end

    assert_equal user.email, account.account_invitations.last.email
  end

  test "an invited parent with an empty family joins and their old family is archived" do
    user = users(:twofactor)
    source = user.family
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: users(:user_without_billing_address), name: user.name, email: user.email)
    sign_in user

    patch account_invitation_path(invitation)

    assert_equal accounts(:invited), user.reload.family
    assert source.reload.archived_at.present?
  end

  test "an invited parent whose family has another parent is told to contact support" do
    user = users(:one)
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: users(:user_without_billing_address), name: user.name, email: user.email)
    sign_in user

    patch account_invitation_path(invitation)

    assert_equal "Your family has another parent. Contact support to join a new family.", flash[:alert]
  end
end
