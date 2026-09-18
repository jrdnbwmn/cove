require "test_helper"

class CheckoutsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = @user.family
    @plan = plans(:personal)

    sign_in @user
    @account.set_payment_processor(:stripe, processor_id: "cus_test")
  end

  test "staging user can open Stripe checkout without sandbox terms consent" do
    checkout_args = capture_checkout_args(staging: true)

    assert_response :success
    assert_not checkout_args.key?(:consent_collection)
  end

  test "non-staging Stripe checkout still requires terms consent" do
    checkout_args = capture_checkout_args(staging: false)

    assert_response :success
    assert_equal({terms_of_service: :required}, checkout_args[:consent_collection])
  end

  test "Premium monthly checkout starts with no trial" do
    plan = plans(:premium_monthly)
    checkout_args = capture_checkout_args(staging: false, plan: plan)

    assert_response :success
    assert_not checkout_args[:subscription_data].key?(:trial_period_days)
    assert_equal plan.stripe_id, checkout_args[:line_items].first[:price]
  end

  test "Premium yearly checkout starts with no trial" do
    plan = plans(:premium_yearly)
    checkout_args = capture_checkout_args(staging: false, plan: plan)

    assert_response :success
    assert_not checkout_args[:subscription_data].key?(:trial_period_days)
    assert_equal plan.stripe_id, checkout_args[:line_items].first[:price]
  end

  private

  def capture_checkout_args(staging:, plan: @plan)
    checkout_args = nil
    checkout_session = Struct.new(:client_secret).new("cs_test_secret")

    Stripe::Checkout::Session.stub(:create, ->(args, *) {
      checkout_args = args
      checkout_session
    }) do
      Rails.env.stub(:staging?, staging) do
        get checkout_path(plan: plan)
      end
    end

    checkout_args
  end
end
