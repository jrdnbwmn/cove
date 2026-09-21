require "test_helper"

class Jumpstart::PublicTest < ActionDispatch::IntegrationTest
  test "homepage" do
    get root_path
    assert_response :success
    assert_not_includes response.body, 'data-controller="theme'
    assert_not_includes response.body, "data-theme-preference-value"
    assert_not_includes response.body, 'classList.toggle("dark"'
  end

  test "signed-out homepage shows the hero, value points, and pricing" do
    get root_path

    assert_response :success
    assert_select "h1", text: I18n.t("public.index.headline")
    assert_select "a[href=?]", new_user_registration_path, text: I18n.t("public.index.cta")
    assert_select "h3", text: I18n.t("public.index.value_points.plan.heading")
    assert_select "h3", text: I18n.t("public.index.value_points.records.heading")
    assert_select "h3", text: I18n.t("public.index.value_points.day.heading")
    assert_select "[data-controller='pricing'] button[data-frequency='monthly']"
    assert_select "[data-controller='pricing']", text: /#{I18n.t("pricing.show.free.name")}/
    assert_select "h2", text: I18n.t("public.index.pricing_heading")
  end

  test "homepage has no Jumpstart text outside the footer" do
    get root_path

    doc = Nokogiri::HTML(response.body)
    doc.css("footer").each(&:remove)
    assert_not_includes doc.at_css("body").text, "Jumpstart"
  end

  test "homepage navbar is borderless and shows the text wordmark" do
    get root_path

    assert_select "nav[aria-label='Primary']" do |navs|
      assert_not_includes navs.first["class"].split, "border-b"
    end
    assert_select "nav[aria-label='Primary'] a[href='/']:first-of-type" do |links|
      assert_equal "Cove", links.first.text.strip
    end
    assert_select "nav[aria-label='Primary'] a[href='/'] svg", count: 0
  end

  test "homepage omits the pricing section when there are no visible plans" do
    Plan.update_all(hidden: true)
    get root_path

    assert_response :success
    assert_select "h1", text: I18n.t("public.index.headline")
    assert_select "h3", text: I18n.t("public.index.value_points.plan.heading")
    assert_select "[data-controller='pricing']", count: 0
    assert_select "h2", text: I18n.t("public.index.pricing_heading"), count: 0
  end

  test "dashboard" do
    sign_in users(:one)
    get root_path
    assert_response :success
  end

  test "pricing page navbar is borderless and shows the text wordmark" do
    get pricing_path

    assert_response :success
    assert_select "nav[aria-label='Primary']" do |navs|
      assert_not_includes navs.first["class"].split, "border-b"
    end
    assert_select "nav[aria-label='Primary'] a[href='/']:first-of-type" do |links|
      assert_equal "Cove", links.first.text.strip
    end
    assert_select "nav[aria-label='Primary'] a[href='/'] svg", count: 0
    assert_select "nav[aria-label='Primary'] a[href='/'] .sr-only", count: 0
  end

  test "about page keeps the standard navbar with logo and border" do
    get about_path

    assert_response :success
    assert_select "nav[aria-label='Primary'].border-b"
    assert_select "nav[aria-label='Primary'] a[href='/'] svg"
  end

  test "signed-in pages keep the standard navbar with logo and border" do
    sign_in users(:one)
    get edit_user_registration_path

    assert_response :success
    assert_select "nav[aria-label='Primary'].border-b"
    assert_select "nav[aria-label='Primary'] a[href='/'] svg"
  end

  test "terms page shows the terms of service" do
    get terms_path

    assert_response :success
    assert_select "h1", text: I18n.t("public.terms.title")
  end

  test "about page renders" do
    get about_path

    assert_response :success
  end

  test "reset app page returns the redirecting placeholder" do
    get reset_app_path

    assert_response :success
    assert_includes response.body, "Redirecting..."
  end

  test "privacy policy explains OAuth data, marketing consent, and service providers" do
    get privacy_path

    assert_response :success
    assert_select "h2", text: "Information we collect"
    assert_select "h2", text: "Google sign-in"
    assert_select "h2", text: "Marketing choices"
    assert_select "h2", text: "Questions about your privacy"
    assert_includes response.body, "Stripe"
    assert_includes response.body, "Loops"
    assert_includes response.body, "Honeybadger"
    assert_includes response.body, "support@covehomeschool.com"
    assert_not_includes response.body, "Some suggestions to help create your Privacy Policy"
  end
end
