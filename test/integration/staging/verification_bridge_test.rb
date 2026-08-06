require "test_helper"

class VerificationBridgeTest < ActionDispatch::IntegrationTest
  OPERATOR_EMAIL = "subscribed@example.com"
  BASE_PATH = "/staging/verification"

  setup do
    @operator = users(:subscribed)
    @non_operator = users(:two)
  end

  test "does not expose verification operations outside staging" do
    with_operator_email do
      post "#{BASE_PATH}/status"
    end

    assert_response :not_found
  end

  test "redirects an unauthenticated visitor from every verification operation" do
    with_staging_environment do
      verification_paths.each do |path|
        post path

        assert_response :redirect, "expected #{path} to require authentication"
      end
    end
  end

  test "returns not found to an authenticated non-operator" do
    sign_in @non_operator

    with_staging_environment do
      post "#{BASE_PATH}/status"
    end

    assert_response :not_found
  end

  test "returns not found when the operator environment variable is missing or blank" do
    sign_in @operator

    [nil, ""].each do |operator_email|
      with_staging_environment(operator_email:) do
        post "#{BASE_PATH}/status"
      end

      assert_response :not_found
    end
  end

  test "allows the operator to invoke each named operation" do
    sign_in @operator

    with_staging_environment do
      verification_paths.each do |path|
        post path, params: {price_id: "price_cov47", to: "third-party@example.com", model: "User"}

        assert_response :success, "expected #{path} to be available to the operator"
      end
    end
  end

  test "creates only the named COV-47 plan from a Stripe price identifier" do
    sign_in @operator

    with_staging_environment do
      assert_difference -> { Plan.where(name: "COV-47 Verification (Yearly)").count }, 1 do
        post "#{BASE_PATH}/create_plan", params: {price_id: "price_cov47", name: "Untrusted", to: "third-party@example.com"}
      end
    end

    assert_response :success
    plan = Plan.find_by!(name: "COV-47 Verification (Yearly)")
    assert_equal "price_cov47", plan.stripe_id
    assert_equal 9900, plan.amount
    assert_equal "year", plan.interval
  end

  test "replaces the COV-47 plan Stripe price when a corrected price is supplied" do
    Plan.create!(name: "COV-47 Verification (Yearly)", amount: 9900, currency: "usd", interval: "year", stripe_id: "price_stale")
    sign_in @operator

    with_staging_environment do
      assert_no_difference -> { Plan.where(name: "COV-47 Verification (Yearly)").count } do
        post "#{BASE_PATH}/create_plan", params: {price_id: "price_corrected"}
      end
    end

    assert_response :success
    assert_equal "price_corrected", Plan.find_by!(name: "COV-47 Verification (Yearly)").stripe_id
  end

  test "rejects a plan identifier that is not a Stripe price" do
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/create_plan", params: {price_id: "prod_cov47"}
    end

    assert_response :unprocessable_content
    assert_nil Plan.find_by(name: "COV-47 Verification (Yearly)")
  end

  test "reports redacted aggregate status without recipient or credential values" do
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/status"
    end

    assert_response :success
    body = response.body
    assert_includes body, "loops_delivery_enabled"
    assert_includes body, "perform_deliveries"
    assert_not_includes body, OPERATOR_EMAIL
    assert_not_includes body, "billing@example.com"
    assert_not_includes body, "secret"
  end

  test "returns aggregate masked audit findings" do
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/audit"
    end

    assert_response :success
    audit = json_response.fetch("audit")
    assert_kind_of Integer, audit.fetch("recipient_count")
    assert_kind_of Integer, audit.fetch("non_allowlisted_count")
    assert_includes audit.fetch("masked_recipients"), "s***@example.com"
    assert_not_includes response.body, OPERATOR_EMAIL
  end

  test "cleanup removes only COV-47 records belonging to the operator account" do
    named_plan = Plan.create!(name: "COV-47 Verification (Yearly)", amount: 9900, currency: "usd", interval: "year", stripe_id: "price_cov47")
    other_invitation = AccountInvitation.create!(account: accounts(:company), email: @operator.email, name: "Keep", invited_by: users(:one))
    named_invitation = AccountInvitation.create!(account: @operator.personal_account, email: @operator.email, name: "Remove", invited_by: @operator)
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/cleanup", params: {plan_id: plans(:personal).id, email: "third-party@example.com"}
    end

    assert_response :success
    assert_nil Plan.find_by(id: named_plan.id)
    assert_nil AccountInvitation.find_by(id: named_invitation.id)
    assert AccountInvitation.exists?(other_invitation.id)
    assert Plan.exists?(plans(:personal).id)
  end

  test "force-cancels a stray non-COV-47 subscription immediately" do
    sign_in @operator
    subscription = pay_subscriptions(:subscribed)

    with_staging_environment do
      post "#{BASE_PATH}/clear_stray_subscription"
    end

    assert_response :success
    assert_equal 1, json_response.fetch("canceled_count")
    assert subscription.reload.canceled?
    assert subscription.ends_at <= Time.current
  end

  test "clear_stray_subscription leaves the COV-47 plan's own subscription alone" do
    plan = Plan.create!(name: "COV-47 Verification (Yearly)", amount: 9900, currency: "usd", interval: "year", stripe_id: "price_cov47", fake_processor_id: "price_cov47")
    subscription = pay_subscriptions(:subscribed)
    subscription.update!(processor_plan: plan.fake_processor_id)
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/clear_stray_subscription"
    end

    assert_response :success
    assert_equal 0, json_response.fetch("canceled_count")
    assert_not subscription.reload.canceled?
  end

  test "immediately cancels the COV-47 verification subscription" do
    plan = Plan.create!(name: "COV-47 Verification (Yearly)", amount: 9900, currency: "usd", interval: "year", stripe_id: "price_cov47", fake_processor_id: "price_cov47")
    subscription = pay_subscriptions(:subscribed)
    subscription.update!(processor_plan: plan.fake_processor_id)
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/cancel_verification_subscription"
    end

    assert_response :success
    assert_equal 1, json_response.fetch("canceled_count")
    assert subscription.reload.canceled?
    assert subscription.ends_at <= Time.current
  end

  test "removes the operator account's stripe customer so a fresh one is created" do
    stale_customer = Pay::Customer.create!(owner: @operator.personal_account, processor: :stripe, processor_id: "cus_stale", default: true)
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/reset_stripe_customer"
    end

    assert_response :success
    assert_equal 1, json_response.fetch("removed_count")
    assert_nil Pay::Customer.find_by(id: stale_customer.id)
  end

  test "reset_stripe_customer leaves other processors' customers alone" do
    sign_in @operator

    with_staging_environment do
      post "#{BASE_PATH}/reset_stripe_customer"
    end

    assert_response :success
    assert_equal 0, json_response.fetch("removed_count")
    assert Pay::Customer.exists?(pay_customers(:subscribed).id)
  end

  test "uses the operator account and fixed mailer actions without recipient or model selection" do
    sign_in @operator
    subscription = pay_subscriptions(:subscribed)
    customer = pay_customers(:subscribed)
    delivery = Minitest::Mock.new
    delivery.expect :deliver_now, true
    mailer = Minitest::Mock.new
    mailer.expect :subscription_renewing, delivery
    captured_arguments = nil

    with_staging_environment do
      Pay::UserMailer.stub(:with, ->(**arguments) {
        captured_arguments = arguments
        mailer
      }) do
        post "#{BASE_PATH}/subscription_renewing", params: {
          to: "third-party@example.com", user_id: users(:two).id, subscription_id: subscription.id, model: "Pay::Subscription"
        }
      end
    end

    assert_response :success
    mailer.verify
    delivery.verify
    assert_equal @operator.personal_account, customer.owner
    assert_equal customer, captured_arguments.fetch(:pay_customer)
    assert_equal subscription, captured_arguments.fetch(:pay_subscription)
  end

  test "uses fixed trial and cancellation mailer actions and restores the trial end" do
    sign_in @operator
    subscription = pay_subscriptions(:subscribed)
    customer = pay_customers(:subscribed)
    will_end_delivery = Minitest::Mock.new
    will_end_delivery.expect :deliver_now, true
    will_end_mailer = Minitest::Mock.new
    will_end_mailer.expect :subscription_trial_will_end, will_end_delivery
    cancellation_delivery = Minitest::Mock.new
    cancellation_delivery.expect :deliver_now, true
    cancellation_mailer = Minitest::Mock.new
    cancellation_mailer.expect :cancellation_reason, cancellation_delivery

    with_staging_environment do
      Pay::UserMailer.stub(:with, will_end_mailer) do
        post "#{BASE_PATH}/subscription_trial_will_end", params: {to: "third-party@example.com"}
      end
      AccountMailer.stub(:with, cancellation_mailer) do
        post "#{BASE_PATH}/cancellation_reason", params: {user_id: users(:two).id}
      end
    end

    assert_response :success
    will_end_mailer.verify
    will_end_delivery.verify
    cancellation_mailer.verify
    cancellation_delivery.verify
    assert_nil subscription.reload.trial_ends_at
    assert_equal @operator.personal_account, customer.owner
  end

  private

  def verification_paths
    %w[
      status
      audit
      create_plan
      invite
      subscription_renewing
      subscription_trial_will_end
      subscription_trial_ended
      cancellation_reason
      enqueue_failure
      cleanup
      clear_stray_subscription
      cancel_verification_subscription
      reset_stripe_customer
    ].map { |action| "#{BASE_PATH}/#{action}" }
  end

  def with_operator_email
    previous = ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"]
    ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"] = OPERATOR_EMAIL

    yield
  ensure
    ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"] = previous
  end

  def with_staging_environment(operator_email: OPERATOR_EMAIL)
    previous = ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"]
    ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"] = operator_email

    Rails.env.stub(:staging?, true) { yield }
  ensure
    ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"] = previous
  end
end
