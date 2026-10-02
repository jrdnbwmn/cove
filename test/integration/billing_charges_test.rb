require "test_helper"

class BillingChargesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:subscribed)
    @customer = pay_customers(:subscribed)
    sign_in @user
  end

  test "billing history paginates charges" do
    13.times do |index|
      @customer.charge((index + 1) * 100, created_at: (13 - index).days.ago)
    end

    get billing_path

    assert_response :success
    assert_select "tbody tr", count: 12
    assert_select "a[href*='page=2']"
    assert_not_includes response.body, "$1.00"

    get billing_path(page: 2)

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_includes response.body, "$1.00"
  end

  test "billing page skips charge history when the family has no subscription" do
    sign_in users(:one)

    get billing_path

    assert_response :success
    assert_not_includes response.body, I18n.t("billing.charges.title")
  end

  test "billing history shows an empty state when there are no charges" do
    get billing_path

    assert_response :success
    assert_includes response.body, I18n.t("billing.charges.empty")
  end
end
