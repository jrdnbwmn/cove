require "application_system_test_case"

class AccountSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    login_as @user, scope: :user
  end

  test "can upload avatar" do
    assert_not @user.avatar.attached?
    visit edit_user_registration_path
    attach_file "user[avatar]", file_fixture("avatar.jpg")
    click_button I18n.t("devise.registrations.edit.update")

    assert_selector "[role='status']", text: I18n.t("devise.registrations.updated")
    assert @user.reload.avatar.attached?
    assert_selector "[data-controller='sidebar'] img[alt='#{@user.name}']"
  end

  test "a parent changes the shared time zone inside the Family modal" do
    visit account_path(accounts(:company))
    click_button "Edit Family"
    assert_selector "dialog[open] select[name='account[time_zone]']", visible: :all
    find("#account_time_zone + .ts-wrapper .ts-control").click
    assert_selector "dialog[open] .ts-dropdown [data-value='Eastern Time (US & Canada)']", visible: :all
    find("dialog[open] .ts-dropdown [data-value='Eastern Time (US & Canada)']").click
    wait_for_turbo_navigation { click_button I18n.t("helpers.submit.update", model: Account.model_name.human) }
    assert_equal "Eastern Time (US & Canada)", accounts(:company).reload.time_zone
    assert_no_selector "dialog[open]"
  end
end
