require "application_system_test_case"

class PricingAndBillingSystemTest < ApplicationSystemTestCase
  setup do
    @premium_monthly = plans(:premium_monthly)
    @premium_yearly = plans(:premium_yearly)
    Plan.visible.where.not(id: [@premium_monthly.id, @premium_yearly.id]).update_all(hidden: true)
  end

  test "Free family sees Free as its current plan and can upgrade" do
    login_as users(:one), scope: :user
    visit pricing_path

    within pricing_group("monthly") do
      assert_text "Free"
      assert_button I18n.t("pricing.show.free.current_plan"), disabled: true
      assert_link I18n.t("pricing.show.premium.upgrade"), href: checkout_path(plan: @premium_monthly)
    end
  end

  test "Premium family sees its current plan and can switch billing intervals" do
    login_as users(:subscribed), scope: :user
    visit pricing_path

    within pricing_group("monthly") do
      assert_button I18n.t("pricing.show.premium.current_plan"), disabled: true
    end

    find("[data-pricing-target='frequency'][data-frequency='yearly']").click

    within pricing_group("yearly") do
      assert_link I18n.t("pricing.show.premium.change_plan")
      assert_text "$10/mo"
      assert_text "billed $120 yearly"
    end
  end

  test "Premium family reviews a plan change before confirming it" do
    subscription = pay_subscriptions(:subscribed)

    login_as users(:subscribed), scope: :user
    visit edit_billing_subscription_path(subscription)
    find("[data-pricing-target='frequency'][data-frequency='yearly']").click

    within pricing_group("yearly") do
      assert_no_selector("[data-turbo-confirm]")
      click_link I18n.t("billing.subscriptions.plan.change_plan")
    end

    assert_current_path billing_subscription_plan_change_path(subscription, plan: @premium_yearly)
    assert_text I18n.t("billing.subscriptions.plan_changes.show.title", interval: I18n.t("billing.subscriptions.plan_changes.show.yearly"))
  end

  test "Premium family confirms a switch to yearly" do
    subscription = pay_subscriptions(:subscribed)

    login_as users(:subscribed), scope: :user
    visit billing_subscription_plan_change_path(subscription, plan: @premium_yearly)
    click_button I18n.t("billing.subscriptions.plan_changes.show.switch_to_yearly")

    assert_current_path billing_path
    assert_text I18n.t("billing.subscriptions.update.success")
  end

  test "Premium family with a pending monthly switch sees it on Billing and can keep yearly" do
    subscription = pay_subscriptions(:subscribed)
    switch_date = 1.month.from_now
    subscription.update!(object: {"schedule" => {"id" => "sub_sched_system", "phases" => [
      {"start_date" => 1.day.ago.to_i, "items" => [{"price" => @premium_yearly.stripe_id}]},
      {"start_date" => switch_date.to_i, "items" => [{"price" => @premium_monthly.stripe_id}]}
    ]}})

    user = users(:subscribed)
    login_as user, scope: :user
    visit billing_path

    local_switch_date = switch_date.in_time_zone(user.time_zone).to_date
    assert_text I18n.t("billing.show.pending_plan_change_title", date: I18n.l(local_switch_date, format: :long))
    assert_no_link I18n.t("billing.subscriptions.subscription.change_plan")

    # The fixture subscription isn't on Stripe, so releasing is a no-op; this checks the Turbo DELETE round trip.
    click_link I18n.t("billing.subscriptions.subscription.keep_yearly")

    assert_current_path billing_path
    assert_text I18n.t("billing.subscriptions.plan_changes.destroy.success")
  end

  test "signed-out visitor can start Free or get Premium" do
    visit pricing_path

    within pricing_group("monthly") do
      assert_link I18n.t("pricing.show.free.get_started"), href: new_user_registration_path
      assert_link I18n.t("pricing.show.premium.get_premium"), href: checkout_path(plan: @premium_monthly)
    end
  end

  test "complimentary Premium family sees Premium as current without billing controls" do
    login_as users(:complimentary), scope: :user
    visit pricing_path

    within pricing_group("monthly") do
      assert_button I18n.t("pricing.show.premium.current_plan"), disabled: true
      assert_no_link I18n.t("pricing.show.premium.upgrade")
    end
  end

  test "grandfathered Premium family can change plans without seeing an upgrade" do
    login_as users(:old_price), scope: :user
    visit pricing_path

    within pricing_group("monthly") do
      assert_link I18n.t("pricing.show.premium.change_plan")
      assert_no_link I18n.t("pricing.show.premium.upgrade")
    end
  end

  test "Free and paid Families see their billing summaries" do
    login_as users(:one), scope: :user
    visit billing_path
    assert_text I18n.t("billing.show.free_title")
    assert_link I18n.t("billing.show.upgrade"), href: pricing_path

    logout(:user)
    login_as users(:subscribed), scope: :user
    visit billing_path
    assert_text I18n.t("billing.show.premium")
    assert_text "Renews October 15, 2026"
  end

  test "complimentary Family sees no paid billing sections" do
    login_as users(:complimentary), scope: :user
    visit billing_path

    assert_text I18n.t("billing.show.complimentary_premium")
    assert_link I18n.t("billing.show.subscribe"), href: pricing_path
    assert_no_text I18n.t("billing.email.billing_email")
    assert_no_text I18n.t("billing.charges.title")
  end

  test "canceled Family sees the date Premium ends" do
    login_as users(:canceled_in_period), scope: :user
    visit billing_path

    assert_text "Premium until"
    assert_text "October 20, 2026"
  end

  test "second parent sees the same paid billing state" do
    second_parent = User.new(
      email: "second-parent-billing@example.com",
      name: "Second Parent",
      password: UNIQUE_PASSWORD,
      password_confirmation: UNIQUE_PASSWORD,
      terms_of_service: true
    )
    second_parent.invitation_signup = true
    second_parent.save!
    accounts(:subscribed).account_users.create!(user: second_parent, roles: {admin: true})

    login_as second_parent, scope: :user
    visit billing_path

    assert_text I18n.t("billing.show.premium")
    assert_text "Renews October 15, 2026"
  end

  test "Premium family updates billing email and information" do
    account = accounts(:subscribed)
    account.update!(billing_email: nil, extra_billing_info: "Cove Family")

    login_as users(:subscribed), scope: :user
    visit billing_path

    fill_in "Billing email", with: "billing@example.com"
    click_button "Save"

    assert_equal "billing@example.com", account.reload.billing_email
    visit billing_path

    page.document.synchronize do
      connected = page.evaluate_script("(() => { const button = Array.from(document.querySelectorAll('button')).find((element) => element.textContent.trim() === 'Edit'); return !!button && !!window.Stimulus?.getControllerForElementAndIdentifier(button.closest(\"[data-controller~='ui-modal']\"), 'ui-modal') })()")
      raise Capybara::ExpectationNotMet, "billing info modal is not connected" unless connected
    end
    click_button "Edit"

    within "dialog[open]" do
      assert_field "Extra billing info", with: "Cove Family"
      fill_in "Extra billing info", with: "Cove Family\nVAT ID 123"
      click_button "Save information"
    end

    assert_equal "Cove Family\nVAT ID 123", account.reload.extra_billing_info
  end

  test "refund policy appears on pricing, checkout, and cancellation" do
    user = users(:one)
    user.family.set_payment_processor(:stripe, processor_id: "cus_test")
    login_as user, scope: :user

    visit pricing_path
    assert_link I18n.t("pricing.show.refund_policy"), href: refunds_path

    with_stubbed_stripe_session { visit checkout_path(plan: @premium_monthly) }
    assert_link I18n.t("pricing.show.refund_policy"), href: refunds_path
    assert_selector "a[href='#{refunds_path}'][target='_blank']"
    assert_selector "a[href='#{terms_path}'][target='_blank']"

    login_as users(:subscribed), scope: :user
    visit billing_subscription_cancel_path(pay_subscriptions(:subscribed))
    assert_text "Your plan will be canceled on 15 Oct."
    assert_link "Refund policy", href: refunds_path

    pay_subscriptions(:subscribed).update!(current_period_end: nil)
    visit billing_subscription_cancel_path(pay_subscriptions(:subscribed))
    assert_text "Your plan will be canceled at the end of your billing period."
    assert_link "Refund policy", href: refunds_path
  end

  test "no trial wording appears on pricing, checkout, billing, or cancellation" do
    user = users(:one)
    user.family.set_payment_processor(:stripe, processor_id: "cus_test")
    login_as user, scope: :user

    visit pricing_path
    assert_no_text(/trial/i)

    with_stubbed_stripe_session { visit checkout_path(plan: @premium_monthly) }
    assert_no_text(/trial/i)

    login_as users(:subscribed), scope: :user
    visit billing_path
    assert_no_text(/trial/i)

    visit billing_subscription_cancel_path(pay_subscriptions(:subscribed))
    assert_no_text(/trial/i)
  end

  private

  def with_stubbed_stripe_session(&block)
    session = Struct.new(:client_secret).new("cs_test_secret")
    Stripe::Checkout::Session.stub(:create, ->(*) { session }, &block)
  end

  def pricing_group(frequency)
    find("[data-pricing-target='plans'][data-frequency='#{frequency}']")
  end
end
