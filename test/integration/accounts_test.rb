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

  test "a parent cannot update complimentary Premium fields" do
    account = accounts(:one)
    account.update!(complimentary_premium: false, complimentary_premium_note: nil)
    sign_in users(:noaccount)

    patch account_path(account), params: {
      account: {complimentary_premium: "1", complimentary_premium_note: "Attempted parent change"}
    }

    assert_response :bad_request
    assert_not_predicate account.reload, :complimentary_premium?
    assert_nil account.complimentary_premium_note
  end
end
