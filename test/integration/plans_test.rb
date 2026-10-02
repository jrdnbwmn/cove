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

  test "pricing page loads visible plans once" do
    plan_queries = []
    callback = ->(_name, _start, _finish, _id, payload) do
      plan_queries << payload[:sql] if payload[:sql]&.match?(/\ASELECT .* FROM ["`]plans["`]/i)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get pricing_path
    end

    assert_equal 1, plan_queries.count
  end

  test "signed-out visitors get a cached plan grid that expires when plans change" do
    original_perform_caching = ActionController::Base.perform_caching
    original_cache_store = ActionController::Base.cache_store
    original_rails_cache = Rails.cache
    cache_store = ActiveSupport::Cache::MemoryStore.new
    cache_reads = []
    subscriber = ActiveSupport::Notifications.subscribe("cache_read.active_support") do |_name, _start, _finish, _id, payload|
      cache_reads << payload if payload[:key].to_s.include?("pricing-plans")
    end

    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = cache_store
    Rails.cache = cache_store

    plan = plans(:enterprise)
    plan.update!(currency: "usd")
    get pricing_path
    assert_response :success
    assert_includes response.body, plan.name

    get pricing_path
    assert_response :success
    assert cache_reads.any? { it[:hit] }, "expected the second request to read the cached plan grid"

    plan.update!(hidden: true)
    get pricing_path
    assert_response :success
    assert_not_includes response.body, plan.name
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    ActionController::Base.perform_caching = original_perform_caching
    ActionController::Base.cache_store = original_cache_store
    Rails.cache = original_rails_cache
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

  test "free card puts Free forever. in the description and has no price note" do
    get "/pricing"

    assert_includes response.body, "Everything you need to get started. Free forever."
    assert_select "p", text: "forever", count: 0
  end

  test "yearly plan note sits beside the monthly price, baseline aligned" do
    get "/pricing"

    assert_select "[data-frequency='yearly'] .flex.items-baseline" do
      assert_select "span.text-4xl"
      assert_select "span", text: /billed .* yearly/
    end
  end
end
