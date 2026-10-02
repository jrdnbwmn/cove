require "test_helper"

class Pay::Subscription::PlanScheduleTest < ActiveSupport::TestCase
  setup { ::Stripe.api_key = "sk_test_plan_schedule" }

  test "Stripe subscriptions expose plan schedule behavior" do
    assert_respond_to Pay::Stripe::Subscription.new, :schedule_plan_change_at_renewal
    assert_respond_to Pay::Stripe::Subscription.new, :pending_plan_change
    assert_respond_to Pay::Stripe::Subscription.new, :release_schedule!
  end

  test "schedules a monthly plan at renewal without proration" do
    subscription = stripe_subscription
    target_plan = plans(:premium_monthly)

    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules")
      .to_return(json_response(id: "sub_sched_123"))
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123")
      .to_return(json_response(id: "sub_sched_123"))

    subscription.stub(:sync!, true) { subscription.schedule_plan_change_at_renewal(target_plan) }

    assert_requested :post, "https://api.stripe.com/v1/subscription_schedules", body: {from_subscription: subscription.processor_id}
    assert_requested :post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123" do |request|
      body = URI.decode_www_form(request.body).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      assert_equal ["release"], body["end_behavior"]
      assert_equal ["none"], body["proration_behavior"]
      assert_equal ["none"], body["phases[0][proration_behavior]"]
      assert_equal ["none"], body["phases[1][proration_behavior]"]
      assert_equal [subscription.current_period_end.to_i.to_s], body["phases[0][end_date]"]
      assert_equal [target_plan.stripe_id], body["phases[1][items][0][price]"]
    end
  end

  test "releases a half-created schedule when its update fails" do
    subscription = stripe_subscription
    events = []

    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules")
      .to_return do
        events << :create
        json_response(id: "sub_sched_123")
      end
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123")
      .to_return do
        events << :update
        {status: 400, body: {error: {message: "invalid phase"}}.to_json}
      end
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123/release")
      .to_return do
        events << :release
        json_response(id: "sub_sched_123")
      end

    assert_raises(Pay::Error) { subscription.schedule_plan_change_at_renewal(plans(:premium_monthly)) }
    assert_equal [:create, :update, :release], events
  end

  test "reads only a future expanded schedule phase with a known price" do
    travel_to Time.zone.local(2030, 1, 1, 12) do
      subscription = stripe_subscription(object: {"schedule" => {
        "id" => "sub_sched_123",
        "phases" => [
          {"start_date" => 1.day.ago.to_i, "items" => [{"price" => plans(:premium_yearly).stripe_id}]},
          {"start_date" => 1.day.from_now.to_i, "items" => [{"price" => {"id" => plans(:premium_monthly).stripe_id}}]}
        ]
      }})

      pending = subscription.pending_plan_change

      assert_equal plans(:premium_monthly), pending[:plan]
      assert_equal 1.day.from_now.to_i, pending[:starts_at].to_i
      assert_nil stripe_subscription(object: {"schedule" => "sub_sched_123"}).pending_plan_change
      assert_nil stripe_subscription(object: {}).pending_plan_change
      assert_nil stripe_subscription(object: {"schedule" => {"phases" => []}}).pending_plan_change
      assert_nil stripe_subscription(object: {"schedule" => {"phases" => [
        {"start_date" => 1.day.from_now.to_i, "items" => [{"price" => "price_unknown"}]}
      ]}}).pending_plan_change
      assert_nil stripe_subscription(object: {"schedule" => {"id" => "sub_sched_123", "phases" => [
        {"start_date" => 1.day.ago.to_i, "items" => [{"price" => plans(:premium_monthly).stripe_id}]}
      ]}}).pending_plan_change
    end
  end

  test "releases an attached schedule even without a future phase" do
    subscription = stripe_subscription(object: {"schedule" => {"id" => "sub_sched_123", "phases" => []}})
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123/release")
      .to_return(json_response(id: "sub_sched_123"))

    subscription.stub(:sync!, true) { subscription.release_schedule! }

    assert_requested :post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123/release"
  end

  test "only a Stripe yearly subscription changing to monthly is deferred to renewal" do
    assert stripe_subscription.plan_change_at_renewal?(plans(:premium_monthly))
    assert_not stripe_subscription.plan_change_at_renewal?(plans(:premium_yearly))
    assert_not stripe_subscription(plan: plans(:premium_monthly)).plan_change_at_renewal?(plans(:premium_yearly))
    assert_not pay_subscriptions(:subscribed).plan_change_at_renewal?(plans(:premium_monthly))
  end

  test "an unknown current price is not deferred to renewal" do
    subscription = stripe_subscription
    subscription.processor_plan = "price_unknown"

    assert_not subscription.plan_change_at_renewal?(plans(:premium_monthly))
  end

  test "pending plan change is read once and returned in the app time zone" do
    subscription = stripe_subscription(object: {"schedule" => pending_schedule(from: plans(:premium_yearly), to: plans(:premium_monthly))})

    assert_queries_count(1) { 2.times { subscription.pending_plan_change } }
    assert_kind_of ActiveSupport::TimeWithZone, subscription.pending_plan_change[:starts_at]
  end

  test "asking whether a switch is pending does not look up the plan" do
    subscription = stripe_subscription(object: {"schedule" => pending_schedule(from: plans(:premium_yearly), to: plans(:premium_monthly))})

    assert_no_queries { assert subscription.pending_plan_change? }
    assert_not stripe_subscription(object: {"schedule" => {"id" => "sub_sched_123", "phases" => []}}).pending_plan_change?
    assert_not stripe_subscription(object: {}).pending_plan_change?
  end

  test "releasing the schedule clears the remembered pending change" do
    subscription = stripe_subscription(object: {"schedule" => pending_schedule(from: plans(:premium_yearly), to: plans(:premium_monthly), id: "sub_sched_123")})
    stub_request(:post, "https://api.stripe.com/v1/subscription_schedules/sub_sched_123/release")
      .to_return(json_response(id: "sub_sched_123"))
    assert subscription.pending_plan_change

    subscription.stub(:sync!, -> { subscription.object = {"schedule" => nil} }) { subscription.release_schedule! }

    assert_nil subscription.pending_plan_change
  end

  test "releasing the schedule does nothing for a subscription that is not on Stripe" do
    subscription = pay_subscriptions(:subscribed)
    subscription.update!(object: {"schedule" => {"id" => "sub_sched_fake", "phases" => []}})

    assert_nothing_raised { subscription.release_schedule! }
  end

  private

  def pending_schedule(from:, to:, id: "sub_sched_123")
    {
      "id" => id,
      "phases" => [
        {"start_date" => 1.day.ago.to_i, "items" => [{"price" => from.stripe_id}]},
        {"start_date" => 1.day.from_now.to_i, "items" => [{"price" => to.stripe_id}]}
      ]
    }
  end

  def stripe_subscription(object: {"schedule" => nil}, plan: plans(:premium_yearly))
    Pay::Stripe::Subscription.new(
      customer: Pay::Stripe::Customer.new(processor: "stripe", processor_id: "cus_schedule_test"),
      processor_id: "sub_schedule_test",
      processor_plan: plan.stripe_id,
      quantity: 1,
      current_period_start: 1.day.ago,
      current_period_end: 1.year.from_now,
      stripe_account: "acct_test",
      object: object
    )
  end

  def json_response(id:)
    {status: 200, body: {id: id, object: "subscription_schedule"}.to_json}
  end
end
