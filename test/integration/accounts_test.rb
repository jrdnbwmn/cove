require "test_helper"

class Jumpstart::AccountsTest < ActionDispatch::IntegrationTest
  test "removed collection and switching routes are unroutable" do
    sign_in users(:one)
    get "/accounts/new"
    assert_response :not_found
    post "/accounts"
    assert_response :not_found
    patch "/accounts/#{accounts(:company).id}/switch"
    assert_response :not_found
  end

  test "only the owner can delete a family" do
    sign_in users(:two)

    assert_no_difference "Account.count" do
      delete account_path(accounts(:company))
    end
  end

  test "the owner can delete their family" do
    sign_in users(:noaccount)

    assert_difference "Account.count", -1 do
      delete account_path(accounts(:one))
    end

    assert_redirected_to root_path
  end
end
