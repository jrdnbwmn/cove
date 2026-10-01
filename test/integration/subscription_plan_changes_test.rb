require "test_helper"
require_relative "../support/stripe_schedule_helper"

class SubscriptionPlanChangesTest < ActionDispatch::IntegrationTest
  include StripeScheduleHelper

  # Confirmation page

  test "an account admin can open a confirmation for a different plan" do
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(pay_subscriptions(:subscribed), plan: plans(:premium_yearly))

    assert_response :success
    assert_includes response.body, "Your yearly plan starts today."
    assert_select "form[action=?][method=?]", billing_subscription_path(pay_subscriptions(:subscribed)), "post"
    assert_select "input[name=plan][value=?]", plans(:premium_yearly).to_param
  end

  test "a yearly subscriber sees renewal and no-refund copy before switching to monthly" do
    subscription = pay_subscriptions(:subscribed)
    subscription.update!(processor_plan: plans(:premium_yearly).fake_processor_id)
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(subscription, plan: plans(:premium_monthly))

    assert_response :success
    assert_includes response.body, "No refund or credit is issued for the rest of your year."
    assert_includes response.body, "$12.00"
  end

  test "a confirmation rejects the subscription's current plan" do
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(pay_subscriptions(:subscribed), plan: plans(:premium_monthly))

    assert_redirected_to billing_path
  end

  test "a confirmation for an unknown plan goes back to Billing" do
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(pay_subscriptions(:subscribed), plan: "plan_missing")

    assert_redirected_to billing_path
  end

  test "a family cannot open a confirmation for another family's subscription" do
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(pay_subscriptions(:past_due), plan: plans(:premium_yearly))

    assert_redirected_to billing_path
  end

  test "a signed-out visitor is sent to sign in instead of a confirmation" do
    get billing_subscription_plan_change_path(pay_subscriptions(:subscribed), plan: plans(:premium_yearly))

    assert_redirected_to new_user_session_path
  end

  test "a confirmation rejects a hidden plan" do
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(pay_subscriptions(:subscribed), plan: plans(:hidden))

    assert_redirected_to billing_path
  end

  test "a confirmation rejects a plan in a different currency" do
    Plan.update_all(currency: "usd") # fixtures leave currency NULL, which validation forbids in real data
    other_currency = Plan.create!(name: "Premium EUR", amount: 12000, interval: "year", currency: "eur", stripe_id: "premium-yearly-eur", fake_processor_id: "premium-yearly-eur")
    sign_in users(:subscribed)

    get billing_subscription_plan_change_path(pay_subscriptions(:subscribed), plan: other_currency)

    assert_redirected_to billing_path
  end

  test "a family on a hidden legacy plan can still switch to a visible plan" do
    Plan.update_all(currency: "usd") # fixtures leave currency NULL, which validation forbids in real data
    plans(:hidden).update_columns(fake_processor_id: "hidden")
    sign_in users(:old_price)

    get billing_subscription_plan_change_path(pay_subscriptions(:old_price), plan: plans(:premium_yearly))

    assert_response :success
  end

  test "changing to a hidden plan is refused and leaves the subscription unchanged" do
    subscription = pay_subscriptions(:subscribed)
    sign_in users(:subscribed)

    patch billing_subscription_path(subscription), params: {plan: plans(:hidden).to_param}

    assert_redirected_to pricing_path
    assert_equal "premium-monthly", subscription.reload.processor_plan
  end

  # Blocked states

  test "a parent cannot change a plan while its subscription is in the grace period" do
    sign_in users(:canceled_in_period)

    get edit_billing_subscription_path(pay_subscriptions(:canceled_in_period))

    assert_redirected_to billing_path
    assert_equal I18n.t("billing.subscriptions.plan_change_guard.grace_period"), flash[:alert]
  end

  test "a parent cannot change a plan when payment is past due" do
    sign_in users(:past_due)

    get edit_billing_subscription_path(pay_subscriptions(:past_due))

    assert_redirected_to billing_path
    assert_equal I18n.t("billing.subscriptions.plan_change_guard.unavailable"), flash[:alert]
  end

  test "a parent cannot open a confirmation when the subscription is unpaid" do
    sign_in users(:unpaid)

    get billing_subscription_plan_change_path(pay_subscriptions(:unpaid), plan: plans(:premium_yearly))

    assert_redirected_to billing_path
    assert_equal I18n.t("billing.subscriptions.plan_change_guard.unavailable"), flash[:alert]
  end

  test "a parent cannot start another change while a switch is pending" do
    subscription = pay_subscriptions(:subscribed)
    subscription.update!(object: {"schedule" => pending_schedule(from: plans(:premium_yearly), to: plans(:premium_monthly))})
    switch_date = I18n.l(1.year.from_now.to_date, format: :long)
    sign_in users(:subscribed)

    get edit_billing_subscription_path(subscription)
    assert_redirected_to billing_path
    assert_equal I18n.t("billing.subscriptions.plan_change_guard.pending", date: switch_date), flash[:alert]

    get billing_subscription_plan_change_path(subscription, plan: plans(:premium_yearly))
    assert_redirected_to billing_path
    assert_equal I18n.t("billing.subscriptions.plan_change_guard.pending", date: switch_date), flash[:alert]

    patch billing_subscription_path(subscription), params: {plan: plans(:premium_yearly).to_param}
    assert_redirected_to billing_path
    assert_equal I18n.t("billing.subscriptions.plan_change_guard.pending", date: switch_date), flash[:alert]
  end

  # Changing plans

  test "switching a Stripe yearly subscription to monthly schedules the change at renewal" do
    stripe_api_key!
    subscription = stripe_subscription_for(accounts(:subscribed), plan: plans(:premium_yearly))
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules").to_return(status: 200, body: {id: "sub_sched_new", object: "subscription_schedule"}.to_json)
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_new").to_return(status: 200, body: {id: "sub_sched_new", object: "subscription_schedule"}.to_json)
    stub_stripe_sync(subscription)

    sign_in users(:subscribed)
    patch billing_subscription_path(subscription), params: {plan: plans(:premium_monthly).to_param}

    assert_redirected_to billing_path
    assert_requested :post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_new" do |request|
      body = URI.decode_www_form(request.body).to_h
      body["phases[1][items][0][price]"] == plans(:premium_monthly).stripe_id && body["proration_behavior"] == "none"
    end
    # A subscription update here would clear a pending cancellation and prorate; only schedule calls are allowed.
    assert_not_requested :post, "https://api.stripe.com/v1/subscriptions/#{subscription.processor_id}"
  end

  test "switching a Stripe monthly subscription to yearly releases any schedule, then swaps immediately with proration" do
    stripe_api_key!
    subscription = stripe_subscription_for(accounts(:subscribed), plan: plans(:premium_monthly), schedule: {"id" => "sub_sched_old", "phases" => []})
    events = []
    stub_stripe_release("sub_sched_old", events: events)
    stub_stripe_sync(subscription, events: events)
    stub_request(:post, "https://api.stripe.com/v1/subscriptions/#{subscription.processor_id}").to_return {
      events << :swap
      {status: 200, body: stripe_subscription_json(subscription, plan: plans(:premium_yearly)).to_json}
    }

    sign_in users(:subscribed)
    patch billing_subscription_path(subscription), params: {plan: plans(:premium_yearly).to_param}

    assert_redirected_to billing_path
    assert_operator events.index(:release), :<, events.index(:swap)
    assert_requested :post, "https://api.stripe.com/v1/subscriptions/#{subscription.processor_id}" do |request|
      URI.decode_www_form(request.body).to_h["proration_behavior"] == "always_invoice"
    end
    assert_not_requested :post, "https://api.stripe.com/v1/subscription_schedules"
  end

  # Keep yearly

  test "an account admin can keep yearly, which releases the pending switch" do
    stripe_api_key!
    subscription = stripe_subscription_for(
      accounts(:subscribed), plan: plans(:premium_yearly),
      schedule: pending_schedule(from: plans(:premium_yearly), to: plans(:premium_monthly), id: "sub_sched_keep")
    )
    stub_stripe_release("sub_sched_keep")
    stub_stripe_sync(subscription)

    sign_in users(:subscribed)
    delete billing_subscription_plan_change_path(subscription)

    assert_redirected_to billing_path
    assert_response :see_other
    assert_equal I18n.t("billing.subscriptions.plan_changes.destroy.success"), flash[:notice]
    assert_requested :post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_keep/release"
  end

  test "keeping yearly shows a fixed message instead of Stripe's error when the release fails" do
    stripe_api_key!
    subscription = stripe_subscription_for(
      accounts(:subscribed), plan: plans(:premium_yearly),
      schedule: pending_schedule(from: plans(:premium_yearly), to: plans(:premium_monthly), id: "sub_sched_keep")
    )
    stub_stripe_release("sub_sched_keep", status: 400)

    sign_in users(:subscribed)
    delete billing_subscription_plan_change_path(subscription)

    assert_redirected_to billing_path
    assert_response :see_other
    assert_equal I18n.t("billing.subscriptions.plan_changes.destroy.failure"), flash[:alert]
    assert_not_includes flash[:alert], "req_secret"
  end

  test "keeping yearly with nothing pending just goes back to Billing" do
    sign_in users(:subscribed)

    delete billing_subscription_plan_change_path(pay_subscriptions(:subscribed))

    assert_redirected_to billing_path
    assert_nil flash[:notice]
  end

  test "a family cannot keep yearly on another family's subscription" do
    sign_in users(:subscribed)

    delete billing_subscription_plan_change_path(pay_subscriptions(:past_due))

    assert_redirected_to billing_path
    assert_nil flash[:notice]
  end
end
