require "test_helper"
require_relative "../support/stripe_schedule_helper"

class SubscriptionScheduleCancellationTest < ActionDispatch::IntegrationTest
  include StripeScheduleHelper

  test "a cancel page explains that a pending monthly switch will be removed" do
    subscription = pay_subscriptions(:subscribed)
    switch_date = subscription.current_period_end
    subscription.update!(object: {
      "schedule" => {
        "id" => "sub_sched_pending_switch",
        "phases" => [
          {"start_date" => subscription.current_period_start.to_i, "items" => [{"price" => plans(:premium_yearly).stripe_id}]},
          {"start_date" => switch_date.to_i, "items" => [{"price" => plans(:premium_monthly).stripe_id}]}
        ]
      }
    })

    sign_in users(:subscribed)
    get billing_subscription_cancel_path(subscription)

    assert_response :success
    assert_includes response.body, I18n.t("billing.subscriptions.cancels.show.pending_plan_change", date: ApplicationController.helpers.friendly_date(switch_date))
  end

  test "a cancel page does not mention a switch when none is pending" do
    sign_in users(:subscribed)

    get billing_subscription_cancel_path(pay_subscriptions(:subscribed))

    assert_response :success
    assert_not_includes response.body, "will also be removed"
  end

  test "a failed cancellation shows a fixed message instead of Stripe's error" do
    stripe_api_key!
    subscription = stripe_subscription_for(accounts(:subscribed), plan: plans(:premium_yearly), schedule: {"id" => "sub_sched_cancel", "phases" => []})
    stub_stripe_release("sub_sched_cancel", status: 400)

    sign_in users(:subscribed)
    delete billing_subscription_cancel_path(subscription)

    assert_response :unprocessable_content
    assert_equal I18n.t("billing.subscriptions.cancels.destroy.failure"), flash[:alert]
    assert_not_includes flash[:alert], "req_secret"
  end

  test "cancelling a scheduled Stripe subscription releases the schedule first" do
    stripe_api_key!
    subscription = stripe_subscription_for(accounts(:subscribed), plan: plans(:premium_yearly), schedule: {"id" => "sub_sched_cancel", "phases" => []})
    events = []
    stub_stripe_release("sub_sched_cancel", events: events)
    stub_stripe_sync(subscription, events: events)
    stub_request(:post, "https://api.stripe.com/v1/subscriptions/#{subscription.processor_id}").to_return {
      events << :cancel
      {status: 200, body: stripe_subscription_json(subscription, "cancel_at" => subscription.current_period_end.to_i, "cancel_at_period_end" => true).to_json}
    }

    sign_in users(:subscribed)
    delete billing_subscription_cancel_path(subscription)

    assert_redirected_to billing_path
    assert_equal [:release, :sync, :cancel], events
  end
end
