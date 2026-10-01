# Builders for Stripe-backed subscriptions plus the Stripe JSON they sync to, for tests that assert
# subscription schedule requests with WebMock. Fixture subscriptions use the fake processor, so
# anything that must reach Stripe builds its own subscription here.
module StripeScheduleHelper
  def stripe_api_key!
    ::Stripe.api_key = "sk_test_stripe_schedule_helper"
  end

  # schedule: nil for none, or a Hash like {"id" => "sub_sched_1", "phases" => [...]} stored on the subscription.
  def stripe_subscription_for(account, plan:, schedule: nil)
    customer = Pay::Stripe::Customer.create!(
      owner: account, processor: "stripe", processor_id: "cus_schedule_test", default: true
    )
    Pay::Stripe::Subscription.create!(
      customer: customer, name: "default", processor_id: "sub_schedule_test", processor_plan: plan.stripe_id,
      quantity: 1, status: "active", current_period_start: 1.day.ago, current_period_end: 1.year.from_now,
      object: {"schedule" => schedule}
    )
  end

  # A schedule whose second phase has not started yet, i.e. a pending switch to target_plan.
  def pending_schedule(from:, to:, id: "sub_sched_pending")
    {
      "id" => id,
      "phases" => [
        {"start_date" => 1.day.ago.to_i, "items" => [{"price" => from.stripe_id}]},
        {"start_date" => 1.year.from_now.to_i, "items" => [{"price" => to.stripe_id}]}
      ]
    }
  end

  def stripe_subscription_json(subscription, plan: nil, **overrides)
    price_id = plan ? plan.stripe_id : subscription.processor_plan
    {
      "id" => subscription.processor_id, "object" => "subscription", "customer" => subscription.customer.processor_id,
      "created" => Time.current.to_i, "status" => "active", "metadata" => {}, "cancel_at" => nil,
      "cancel_at_period_end" => false, "ended_at" => nil, "trial_end" => nil, "pause_collection" => nil,
      "default_payment_method" => nil, "schedule" => nil,
      "latest_invoice" => {"id" => "in_schedule_test", "object" => "invoice",
                           "payments" => {"object" => "list", "data" => [], "has_more" => false, "url" => "/v1/invoices/in_schedule_test/payments"}},
      "items" => {"object" => "list", "has_more" => false, "url" => "/v1/subscription_items", "data" => [{
        "id" => "si_schedule_test", "object" => "subscription_item", "quantity" => 1,
        "current_period_start" => subscription.current_period_start.to_i, "current_period_end" => subscription.current_period_end.to_i,
        "price" => {"id" => price_id, "recurring" => {"usage_type" => "licensed"}}
      }]}
    }.merge(overrides)
  end

  def stub_stripe_release(schedule_id, events: nil, status: 200)
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/#{schedule_id}/release").to_return {
      events&.push(:release)
      {status: status, body: ((status == 200) ? {id: schedule_id, object: "subscription_schedule"} : {error: {message: "No such schedule: #{schedule_id} (req_secret)"}}).to_json}
    }
  end

  def stub_stripe_sync(subscription, events: nil, **json_options)
    stub_request(:get, %r{https://api\.stripe\.com/v1/subscriptions/#{subscription.processor_id}}).to_return {
      events&.push(:sync)
      {status: 200, body: stripe_subscription_json(subscription, **json_options).to_json}
    }
  end
end
