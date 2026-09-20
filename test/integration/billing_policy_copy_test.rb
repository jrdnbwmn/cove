require "test_helper"

class BillingPolicyCopyTest < ActionDispatch::IntegrationTest
  test "a paid Family shows the immediate Premium cancellation consequence on both Family pages" do
    account = accounts(:subscribed)
    sign_in users(:subscribed)

    [account_path(account), edit_account_path(account)].each do |path|
      get path

      assert_response :success
      assert_select "button[data-turbo-confirm-description=?]", "Deleting this Family ends Premium immediately and no refund is issued."
    end
  end

  test "a Free Family shows its generic deletion consequence on both Family pages" do
    account = accounts(:company)
    sign_in users(:one)

    [account_path(account), edit_account_path(account)].each do |path|
      get path

      assert_response :success
      assert_select "button[data-turbo-confirm-description=?]", "Deleting this Family permanently removes its data."
    end
  end

  test "an owner deleting a paid Family login sees the Premium cancellation consequence" do
    sign_in users(:subscribed)

    get edit_user_registration_path

    assert_response :success
    assert_includes response.body, "Deleting your login ends Premium immediately and no refund is issued."
    assert_includes response.body, 'data-turbo-confirm-description="Deleting your login ends Premium immediately and no refund is issued.'
  end

  test "a second parent deleting a login sees that the Family and subscription are unchanged" do
    account_users(:two).destroy!
    sign_in users(:two)

    get edit_user_registration_path

    assert_response :success
    assert_includes response.body, "Deleting your login leaves the Family and subscription unchanged."
    assert_includes response.body, 'data-turbo-confirm-description="Deleting your login leaves the Family and subscription unchanged.'
  end
end
