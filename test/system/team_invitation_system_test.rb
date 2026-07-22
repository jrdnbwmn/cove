require "application_system_test_case"

class TeamInvitationSystemTest < ApplicationSystemTestCase
  test "account admin can invite a teammate who joins the account" do
    account = accounts(:company)
    invitee = users(:noaccount)
    email = invitee.email

    login_as users(:one), scope: :user
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

    assert_current_path accounts_path
    assert account.users.reload.include?(invitee)
  end
end
