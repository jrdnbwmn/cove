require "test_helper"

class Madmin::AccountsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @account = accounts(:one)
  end

  test "superadmin sees the student limit on edit and show but not index" do
    get edit_madmin_account_path(@account)

    assert_response :success
    assert_select "input[type=number][name='account[student_limit]'][value='#{@account.student_limit}']"

    get madmin_account_path(@account)

    assert_response :success
    assert_match(
      /<th[^>]*>\s*Student Limit\s*<\/th>\s*<td>\s*#{@account.student_limit}\s*<\/td>/,
      response.body
    )

    get madmin_accounts_path

    assert_response :success
    assert_select "th", {text: "Student Limit", count: 0}
  end

  test "superadmin can update a family student limit" do
    patch madmin_account_path(@account), params: {account: {student_limit: 14}}

    assert_redirected_to madmin_account_path(@account)
    assert_equal 14, @account.reload.student_limit
  end

  test "invalid student limit update shows errors and retains the stored value" do
    stored_limit = @account.student_limit

    patch madmin_account_path(@account), params: {account: {student_limit: 0}}

    assert_response :unprocessable_entity
    assert_includes response.body, "Student limit must be greater than or equal to 1"
    assert_equal stored_limit, @account.reload.student_limit
  end
end
