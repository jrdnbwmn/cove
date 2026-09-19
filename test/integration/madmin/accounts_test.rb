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

  test "superadmin sees the complimentary flag on index show and edit but not its note on index" do
    get edit_madmin_account_path(@account)

    assert_response :success
    assert_select "input[type=checkbox][name='account[complimentary_premium]']"
    assert_select "input[name='account[complimentary_premium_note]']"

    get madmin_account_path(@account)

    assert_response :success
    assert_select "th", text: "Complimentary Premium"
    assert_select "th", text: "Complimentary Premium Note"

    get madmin_accounts_path

    assert_response :success
    assert_select "th", text: "Complimentary Premium"
    assert_select "th", {text: "Complimentary Premium Note", count: 0}
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

  test "superadmin can grant complimentary Premium with a note" do
    patch madmin_account_path(@account), params: {
      account: {complimentary_premium: "1", complimentary_premium_note: "Pilot tester cohort"}
    }

    assert_redirected_to madmin_account_path(@account)
    assert_predicate @account.reload, :complimentary_premium?
    assert_equal "Pilot tester cohort", @account.complimentary_premium_note
  end

  test "blank or whitespace complimentary Premium notes show errors and retain stored values" do
    [["", "blank"], ["   ", "whitespace"]].each do |note, description|
      @account.update!(complimentary_premium: false, complimentary_premium_note: "Existing note")

      patch madmin_account_path(@account), params: {
        account: {complimentary_premium: "1", complimentary_premium_note: note}
      }

      assert_response :unprocessable_entity, "#{description} note"
      assert_includes response.body, "Complimentary premium note can't be blank", "#{description} note"
      assert_not_predicate @account.reload, :complimentary_premium?, "#{description} note"
      assert_equal "Existing note", @account.complimentary_premium_note, "#{description} note"
    end
  end

  test "superadmin can revoke complimentary Premium while retaining its note" do
    @account.update!(complimentary_premium: true, complimentary_premium_note: "Pilot tester cohort")

    patch madmin_account_path(@account), params: {
      account: {complimentary_premium: "0", complimentary_premium_note: "Pilot tester cohort"}
    }

    assert_redirected_to madmin_account_path(@account)
    assert_not_predicate @account.reload, :complimentary_premium?
    assert_equal "Pilot tester cohort", @account.complimentary_premium_note
  end

  test "non-superadmin cannot access complimentary Premium administration" do
    sign_in users(:one)

    get madmin_account_path(@account)

    assert_response :not_found
  end
end
