require "test_helper"

class Jumpstart::PlansTest < ActionDispatch::IntegrationTest
  fixtures :plans

  test "redirects when there are no plans" do
    Plan.delete_all
    get "/pricing"
    assert_redirected_to root_url
  end

  test "view pricing page when there are plans" do
    get "/pricing"

    Plan.visible.find_each do |plan|
      assert_includes response.body, plan.name
    end
  end

  test "pricing page uses the Premium action label" do
    get "/pricing"

    assert_select "a[href=?]", checkout_path(plan: plans(:personal)), text: I18n.t("pricing.show.premium.get_premium")
  end

  test "enterprise plan shows up" do
    get "/pricing"

    assert_select "a[href=?]", "mailto:user@example.com"
    assert_select "a", text: I18n.t("billing.subscriptions.plan.contact_us")
    assert_select "span", text: I18n.t("billing.subscriptions.plan.contact_us_price")
  end

  test "pricing page shows the frequency toggle, Free card, and Premium card" do
    get "/pricing"

    assert_select "[data-controller='pricing'] button[data-frequency='monthly']", text: "Monthly"
    assert_select "[data-controller='pricing'] button[data-frequency='yearly']", text: "Yearly"
    assert_select "[data-pricing-target='plans']", text: /#{I18n.t("pricing.show.free.name")}/
    assert_select "a[href=?]", checkout_path(plan: plans(:personal)), text: I18n.t("pricing.show.premium.get_premium")
  end
end
