require "test_helper"

class FamilyInvitationAcceptanceTest < ActiveSupport::TestCase
  test "adds the invited user as an admin and consumes the invitation" do
    invitation = account_invitations(:one)
    user = users(:invited)

    result = FamilyInvitationAcceptance.new(invitation: invitation, user: user).call

    assert_predicate result, :success?
    assert_predicate result.account_user, :admin?
    assert_equal invitation.account, user.family
    assert_not AccountInvitation.exists?(invitation.id)
  end

  test "refuses an invitation accepted by another email address" do
    result = FamilyInvitationAcceptance.new(invitation: account_invitations(:one), user: users(:admin)).call

    assert_not_predicate result, :success?
    assert_equal "This invitation was sent to someone else", result.error
  end

  test "archives an existing joinable family before moving its parent" do
    user = users(:noaccount)
    source = user.family
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: users(:user_without_billing_address), name: user.name, email: user.email)

    result = FamilyInvitationAcceptance.new(invitation: invitation, user: user).call

    assert_predicate result, :success?
    assert source.reload.archived_at.present?
    assert_equal accounts(:invited), user.family
  end

  test "refuses when the invitee is already a member of the target family" do
    user = users(:user_without_billing_address)
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: user, name: user.name, email: user.email)

    result = FamilyInvitationAcceptance.new(invitation: invitation, user: user).call

    assert_not_predicate result, :success?
    assert_equal "You are already in this family", result.error
  end

  test "refuses when the target family already has two parents" do
    user = users(:noaccount)
    invitation = AccountInvitation.create!(account: accounts(:company), invited_by: users(:one), name: user.name, email: user.email)

    result = FamilyInvitationAcceptance.new(invitation: invitation, user: user).call

    assert_not_predicate result, :success?
    assert_equal "Family already has two parents", result.error
  end

  test "refuses with a contact-support message when the invitee's family has another parent" do
    user = users(:one)
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: users(:user_without_billing_address), name: user.name, email: user.email)

    result = FamilyInvitationAcceptance.new(invitation: invitation, user: user).call

    assert_not_predicate result, :success?
    assert_equal "Your family has another parent. Contact support to join a new family.", result.error
    assert_equal accounts(:company), user.family
  end

  test "refuses with a cancel-Premium message when the invitee's family has a billable subscription" do
    user = users(:subscribed)
    source = user.family
    customer = source.set_payment_processor(:fake_processor, allow_fake: true)
    customer.subscribe(plan: "per_seat")
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: users(:user_without_billing_address), name: user.name, email: user.email)

    result = FamilyInvitationAcceptance.new(invitation: invitation, user: user).call

    assert_not_predicate result, :success?
    assert_equal "Cancel your Premium subscription first, then accept this invitation.", result.error
    assert_equal source, user.family
  end

  test "reports a friendly message when a concurrent acceptance wins the race" do
    user = users(:noaccount)
    invitation = AccountInvitation.create!(account: accounts(:invited), invited_by: users(:user_without_billing_address), name: user.name, email: user.email)

    raise_not_unique = ->(*, **) { raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint" }
    result = AccountUser.stub(:new, raise_not_unique) do
      FamilyInvitationAcceptance.new(invitation: invitation, user: user).call
    end

    assert_not_predicate result, :success?
    assert_equal "You already belong to a family", result.error
  end
end
