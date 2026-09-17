require "test_helper"

class Jumpstart::AccountsEditTest < ActionDispatch::IntegrationTest
  test "the family owner sees the delete control" do
    sign_in users(:one)

    get edit_account_path(accounts(:company))

    assert_response :success
    assert_select "form[action=?][method=?]", account_path(accounts(:company)), "post" do
      assert_select "input[name=?][value=?]", "_method", "delete"
      assert_select "button", text: "Delete"
    end
  end

  test "a non-owner admin does not see the delete control" do
    sign_in users(:two)

    get edit_account_path(accounts(:company))

    assert_response :success
    assert_select "form[action=?][method=?] input[name=?][value=?]", account_path(accounts(:company)), "post", "_method", "delete", count: 0
  end

  # AIDEV-NOTE: No "owner viewing a personal account" case here — this app's
  # accounts table has a DB check constraint (accounts_personal_must_be_false,
  # db/schema.rb) that forces personal to always be false, so a personal
  # account fixture cannot exist to test against.
end
