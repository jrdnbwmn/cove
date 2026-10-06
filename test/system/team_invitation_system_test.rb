require "application_system_test_case"

class TeamInvitationSystemTest < ApplicationSystemTestCase
  test "family settings show parents as responsive rows" do
    login_as users(:one), scope: :user
    page.current_window.resize_to(390, 900)
    visit account_path(accounts(:company))

    assert_no_selector "table"
    assert_selector "[data-family-row]", count: 2
    assert_selector "[data-family-row]", text: "Owner"
    assert_button "Invite a parent"
    assert_text "A family can have up to two parents."
    assert_equal evaluate_script("window.innerWidth"), evaluate_script("document.documentElement.scrollWidth")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "owner edits their family in a modal" do
    login_as users(:one), scope: :user
    visit account_path(accounts(:company))

    click_button "Edit Family"
    assert_selector "dialog[open] input[name='account[name]']"
    within "dialog[open]" do
      fill_in "Name", with: "Updated Family"
      click_button "Update Account"
    end
    assert_text "Account was successfully updated."
  end

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

    assert_selector "[role='status']", text: "Invitation was sent to #{email}."
    invitation = account.account_invitations.find_by!(email: email)
    logout(:user)
    login_as invitee, scope: :user
    visit account_invitation_path(invitation)
    find("button[type=submit]", text: I18n.t("account_invitations.show.accept")).click

    assert_current_path account_path(account)
    assert account.users.reload.include?(invitee)
  end

  test "parent invitation opens from Family in a modal" do
    login_as users(:one), scope: :user
    visit account_path(accounts(:company))

    click_button "Invite a parent"
    assert_selector "dialog[open] input[name='account_invitation[email]']"
  end
end
