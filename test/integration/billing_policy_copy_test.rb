require "test_helper"

class BillingPolicyCopyTest < ActionDispatch::IntegrationTest
  test "the billing page tells a Free family it can have 2 students" do
    Jumpstart.config.stub(:payments_enabled?, true) do
      sign_in users(:one)
      get billing_path

      assert_includes response.body, "Your Family can have 2 students."
    end
  end

  test "a past due family's cancel page says the plan ends immediately and offers no resume" do
    sign_in users(:past_due)

    get billing_subscription_cancel_path(pay_subscriptions(:past_due))

    assert_includes response.body, I18n.t("billing.subscriptions.cancels.show.cancel_immediately")
    assert_not_includes response.body, I18n.t("billing.subscriptions.cancels.show.resume")
  end

  test "an active family's cancel page still offers resuming" do
    sign_in users(:subscribed)

    get billing_subscription_cancel_path(pay_subscriptions(:subscribed))

    assert_includes response.body, I18n.t("billing.subscriptions.cancels.show.resume")
  end

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
