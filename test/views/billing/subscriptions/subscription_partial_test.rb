require "test_helper"

# AIDEV-NOTE: Renders billing/subscriptions/_subscription directly (not via billing_path) because
# BillingController#show only queries active/past_due/unpaid subscriptions - incomplete, paused, and
# fully-ended-canceled subscriptions never reach that page, so their badge/action rendering can only
# be exercised by rendering the partial in isolation.
class Billing::Subscriptions::SubscriptionPartialTest < ActionView::TestCase
  helper PlanHelper
  helper Pay::CurrencyHelper

  setup do
    @account = accounts(:one)
    @account.set_payment_processor :fake_processor, allow_fake: true
    @plan = plans(:per_seat)
  end

  def render_subscription(subscription)
    fragment(render(partial: "billing/subscriptions/subscription", locals: {subscription: subscription}))
  end

  def fragment(html)
    Nokogiri::HTML::DocumentFragment.parse(html)
  end

  def subscribe(**attrs)
    subscription = @account.payment_processor.subscribe(plan: @plan.fake_processor_id)
    subscription.update!(**attrs)
    subscription
  end

  test "free trial shows Free Trial badge and trial end date" do
    subscription = subscribe(trial_ends_at: 10.days.from_now)

    doc = render_subscription(subscription)

    assert_equal I18n.t("billing.subscriptions.subscription.free_trial"), doc.css("span").first.text.strip
    assert_includes doc.text, I18n.t("billing.subscriptions.subscription.free_trial_ends", date: l(subscription.trial_ends_at.to_date, format: :long))
  end

  test "canceled subscription shows Canceled badge with no variant color" do
    subscription = subscribe(status: "active", ends_at: 1.day.ago)

    doc = render_subscription(subscription)

    assert_equal I18n.t("billing.subscriptions.subscription.canceled"), doc.css("span").first.text.strip
    refute_match(/text-red-700|text-orange-700/, doc.css("span").first[:class])
  end

  test "incomplete subscription shows Incomplete badge and confirm payment action" do
    subscription = subscribe(status: "incomplete")
    # fake_processor has no #latest_payment (only Pay::Stripe::Subscription defines it);
    # the view's confirm-payment link needs an id, so stub the same accessor Stripe provides.
    subscription.define_singleton_method(:latest_payment) { Struct.new(:id).new("pay_fake_123") }

    doc = render_subscription(subscription)

    assert_equal I18n.t("billing.subscriptions.subscription.incomplete"), doc.css("span").first.text.strip
    link = doc.css("a").find { |a| a.text.strip == I18n.t("billing.subscriptions.subscription.confirm_payment") }
    assert link, "expected a confirm payment link"
    assert_equal pay.payment_path("pay_fake_123"), link[:href]
  end

  test "past due subscription shows red Past due badge and update payment method action" do
    subscription = subscribe(status: "past_due")

    doc = render_subscription(subscription)

    badge = doc.css("span").first
    assert_equal I18n.t("billing.subscriptions.subscription.past_due"), badge.text.strip
    assert_match(/text-red-700/, badge[:class])
    link = doc.css("a").find { |a| a.text.strip == I18n.t("billing.subscriptions.subscription.update_payment_method") }
    assert link, "expected an update payment method link"
    assert_equal new_billing_subscription_payment_method_path(subscription), link[:href]
  end

  test "unpaid subscription shows red Unpaid badge and update payment method action" do
    subscription = subscribe(status: "unpaid")

    doc = render_subscription(subscription)

    badge = doc.css("span").first
    assert_equal I18n.t("billing.subscriptions.subscription.unpaid"), badge.text.strip
    assert_match(/text-red-700/, badge[:class])
    link = doc.css("a").find { |a| a.text.strip == I18n.t("billing.subscriptions.subscription.update_payment_method") }
    assert link, "expected an update payment method link"
    assert_equal new_billing_subscription_payment_method_path(subscription), link[:href]
  end

  test "paused subscription shows paused alert with no top badge and resume action" do
    subscription = subscribe(status: "paused")

    doc = render_subscription(subscription)

    assert_includes doc.text, I18n.t("billing.subscriptions.subscription.paused")
    link = doc.css("a").find { |a| a.text.strip == I18n.t("billing.subscriptions.subscription.resume") }
    assert link, "expected a resume link"
    assert_equal billing_subscription_resume_path(subscription), link[:href]
  end

  test "on grace period subscription shows ends_at alert and resume action" do
    subscription = subscribe(status: "active", ends_at: 5.days.from_now)

    doc = render_subscription(subscription)

    assert_includes doc.text, I18n.t("billing.subscriptions.subscription.ends_at", date: l(subscription.ends_at.to_date, format: :long))
    link = doc.css("a").find { |a| a.text.strip == I18n.t("billing.subscriptions.subscription.resume") }
    assert link, "expected a resume link"
    assert_equal billing_subscription_resume_path(subscription), link[:href]
  end
end
