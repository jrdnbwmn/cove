require "test_helper"

class BillingResilienceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:subscribed)
    sign_in @user
  end

  test "requesting a receipt for an unknown charge returns not found" do
    get billing_charge_path("charge_missing", format: :pdf)

    assert_response :not_found
  end

  test "a parent can't download another family's receipt" do
    other_charge = pay_customers(:fake).charge(1_200)

    get billing_charge_path(other_charge, format: :pdf)

    assert_response :not_found
  end

  test "a receipt is downloaded again after the family's billing details change" do
    charge = pay_customers(:subscribed).charge(1_200)

    get billing_charge_path(charge, format: :pdf)
    etag = response.headers["ETag"]

    travel 1.minute do
      accounts(:subscribed).update!(extra_billing_info: "VAT 123")
    end

    get billing_charge_path(charge, format: :pdf), headers: {"If-None-Match" => etag}

    assert_response :success
  end

  test "requesting an unknown subscription payment method page returns not found" do
    get new_billing_subscription_payment_method_path("subscription_missing")

    assert_response :not_found
  end

  test "repeat receipt download is served from the browser cache" do
    charge = pay_customers(:subscribed).charge(1_200)

    get billing_charge_path(charge, format: :pdf)

    assert_response :success
    assert_not_nil response.headers["ETag"]

    get billing_charge_path(charge, format: :pdf), headers: {"If-None-Match" => response.headers["ETag"]}

    assert_response :not_modified
  end

  test "viewing an announcement does not mark announcements read but the index does" do
    @user.update_column(:announcements_read_at, nil)
    announcement = announcements(:one)

    get announcement_path(announcement)

    assert_response :success
    assert_nil @user.reload.announcements_read_at

    freeze_time do
      get announcements_path

      assert_response :success
      assert_equal Time.current, @user.reload.announcements_read_at
    end
  end
end
