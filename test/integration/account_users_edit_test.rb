require "test_helper"

class AccountUsersEditTest < ActionDispatch::IntegrationTest
  test "parent permissions page is no longer routable" do
    account = accounts(:company)
    member = account_users(:company_regular_user)
    sign_in users(:one)

    get "/accounts/#{account.id}/members/#{member.id}/edit"

    assert_response :not_found
  end
end
