require "application_system_test_case"

class TeamInvitationSystemTest < ApplicationSystemTestCase
  test "account admin can invite a teammate who joins the account" do
    account = accounts(:invited)
    invitee = users(:invited)
    email = invitee.email
    account.account_invitations.destroy_all

    login_as users(:user_without_billing_address), scope: :user
    visit new_account_account_invitation_path(account)
    fill_in "account_invitation[name]", with: "System Invitee"
    fill_in "account_invitation[email]", with: email
    find("button[type=submit]").click

    assert_selector "#flash", text: "Invitation was sent to #{email}."
    invitation = account.account_invitations.find_by!(email: email)
    logout(:user)
    login_as invitee, scope: :user
    visit account_invitation_path(invitation)
    find("button[type=submit]", text: I18n.t("account_invitations.show.accept")).click

    assert_current_path account_path(account)
    assert account.users.reload.include?(invitee)
  end
end
