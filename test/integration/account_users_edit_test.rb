require "test_helper"

class AccountUsersEditTest < ActionDispatch::IntegrationTest
  test "edit permissions page interpolates the member's name into the title" do
    account = accounts(:company)
    member = account_users(:company_regular_user)
    sign_in users(:one)

    get edit_account_account_user_path(account, member)

    assert_response :success
    assert_match "Edit permissions for #{member.user.name}", response.body
    assert_no_match "%{user}", response.body
  end
end
