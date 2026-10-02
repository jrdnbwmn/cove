require "test_helper"

class Jumpstart::PublicTest < ActionDispatch::IntegrationTest
  test "homepage" do
    get root_path
    assert_response :success
    assert_not_includes response.body, 'data-controller="theme'
    assert_not_includes response.body, "data-theme-preference-value"
    assert_not_includes response.body, 'classList.toggle("dark"'
  end

  test "visitors on an older iPad can see the homepage" do
    get root_path, headers: {"User-Agent" => "Mozilla/5.0 (iPad; CPU OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"}

    assert_response :success
  end

  test "terms page shows when it was last updated" do
    get terms_path

    agreement = Rails.application.config.agreements.find { it.id == :terms_of_service }
    assert_select "h1", text: "Terms of Service"
    assert_includes response.body, I18n.t("users.agreements.show.last_updated", date: I18n.l(agreement.updated.to_date, format: :long))
  end

  test "privacy page shows when it was last updated" do
    get privacy_path

    agreement = Rails.application.config.agreements.find { it.id == :privacy_policy }
    assert_select "h1", text: "Privacy Policy"
    assert_includes response.body, I18n.t("users.agreements.show.last_updated", date: I18n.l(agreement.updated.to_date, format: :long))
  end

  test "legal page still renders when its agreement is missing" do
    Rails.application.config.stub(:agreements, []) do
      get terms_path
    end

    assert_response :success
    assert_select "h1"
    assert_not_includes response.body, "Last updated"
  end

  test "legal page headings are not bolded" do
    get terms_path

    assert_select "div.prose.prose-headings\\:font-normal"
  end

  test "refund policy is public and explains cancellation" do
    get refunds_path

    assert_response :success
    assert_select "h1", text: "Refund Policy"
    assert_includes response.body, "Last updated"
    assert_includes response.body, "30 days"
    assert_includes response.body, Jumpstart.config.support_email
    assert_select "a[href=?]", terms_path
  end

  test "signed-out homepage shows the hero, value points, and pricing" do
    get root_path

    assert_response :success
    assert_select "h1"
    assert_includes response.body, I18n.t("public.index.headline_html")
    assert_select "a[href=?]", new_user_registration_path, text: I18n.t("public.index.cta")
    assert_select "h3", text: I18n.t("public.index.value_points.plan.heading")
    assert_select "h3", text: I18n.t("public.index.value_points.records.heading")
    assert_select "h3", text: I18n.t("public.index.value_points.day.heading")
    assert_select "[data-controller='pricing'] button[data-frequency='monthly']"
    assert_select "[data-controller='pricing']", text: /#{I18n.t("pricing.show.free.name")}/
    assert_select "h2", text: I18n.t("public.index.pricing_heading")
  end

  test "homepage value points are cards, each with an icon" do
    get root_path

    cards = css_select("[data-testid='value-point']")
    assert_equal 3, cards.size
    cards.each do |card|
      assert_equal 1, card.css("svg").size
      assert_equal 1, card.css("h3").size
    end
  end

  test "footer shows the Cove logo and the dev menu inline with the links, not in the navbar" do
    Rails.env.stub(:development?, true) do
      get root_path
    end

    assert_select "footer a[href='/'] svg", count: 1
    assert_select "footer a[href='/'] .sr-only", text: "Cove"
    assert_select "footer ul li button[aria-label='Dev Menu']", count: 1
    assert_select "nav[aria-label='Primary'] button[aria-label='Dev Menu']", count: 0
    assert_select "footer button[aria-label='Dev Menu']", count: 1
  end

  test "homepage has no Jumpstart text outside the footer" do
    get root_path

    doc = Nokogiri::HTML(response.body)
    doc.css("footer").each(&:remove)
    assert_not_includes doc.at_css("body").text, "Jumpstart"
  end

  test "homepage navbar is borderless and shows the logo" do
    get root_path

    assert_select "nav[aria-label='Primary']" do |navs|
      assert_not_includes navs.first["class"].split, "border-b"
    end
    assert_select "nav[aria-label='Primary'] a[href='/'] svg", count: 1
    assert_select "nav[aria-label='Primary'] a[href='/'] .sr-only", text: "Cove"
  end

  test "homepage omits the pricing section when there are no visible plans" do
    Plan.update_all(hidden: true)
    get root_path

    assert_response :success
    assert_select "h1"
    assert_includes response.body, I18n.t("public.index.headline_html")
    assert_select "h3", text: I18n.t("public.index.value_points.plan.heading")
    assert_select "[data-controller='pricing']", count: 0
    assert_select "h2", text: I18n.t("public.index.pricing_heading"), count: 0
  end

  test "dashboard" do
    sign_in users(:one)
    get root_path
    assert_response :success
  end

  test "pricing page shows both parents are included on Free and Premium" do
    get pricing_path

    assert_response :success
    assert_not_includes response.body, "One parent"
    assert_includes response.body, ">#{I18n.t("pricing.show.free.both_parents")}<"
  end

  test "the Free pricing card says 2 students" do
    get pricing_path

    assert_includes response.body, ">2 students<"
  end

  test "the Premium pricing card shows unlimited students" do
    get pricing_path

    assert_includes response.body, ">Unlimited students<"
    assert_not_includes response.body, "Up to"
  end

  test "a signed-out visitor is invited to contact support for more than 10 students" do
    get pricing_path

    assert_includes response.body, "More than 10 students?"
    assert_select "a[href^=?]", "mailto:#{Jumpstart.config.support_email}", text: "Contact us"
  end

  test "a raised Premium family sees its own number in the contact line" do
    accounts(:complimentary).update!(student_limit: 14)
    sign_in users(:complimentary)

    get pricing_path

    assert_includes response.body, "More than 14 students?"
  end

  test "pricing page navbar is borderless and shows the logo" do
    get pricing_path

    assert_response :success
    assert_select "nav[aria-label='Primary']" do |navs|
      assert_not_includes navs.first["class"].split, "border-b"
    end
    assert_select "nav[aria-label='Primary'] a[href='/'] svg", count: 1
    assert_select "nav[aria-label='Primary'] a[href='/'] .sr-only", text: "Cove"
  end

  test "about page keeps the standard navbar with logo and border" do
    get about_path

    assert_response :success
    assert_select "nav[aria-label='Primary'].border-b"
    assert_select "nav[aria-label='Primary'] a[href='/'] svg"
  end

  test "signed-in pages render the sidebar shell instead of the top navbar" do
    sign_in users(:one)
    get edit_user_registration_path

    assert_response :success
    assert_select "nav[aria-label='Primary']", count: 0
    assert_select "[data-controller='sidebar']"
    assert_select "button[aria-label='Notifications']", count: 0
    assert_select "footer", count: 0
  end

  test "signed-in dashboard shows the sidebar with Home active" do
    sign_in users(:one)
    get root_path

    assert_response :success
    assert_select "[data-controller='sidebar']"
    assert_select "a[href='#{user_root_path}'][aria-current='page']"
    # Support now lives inside the account menu dropdown, which the sidebar shell renders
    # once for the expanded footer and once for the collapsed footer, plus once more in
    # the mobile drawer nav.
    assert_select "a[href='#{support_path}']", text: "Support", count: 3
    assert_select "a[href^='mailto:']", count: 0
    assert_select "main > div.flex-1.overflow-y-auto.p-0.lg\\:p-3", count: 1
    assert_select "button[aria-label='Open menu'].right-6.bottom-6", count: 1
    assert_select "main > div > div.app-content.p-6", count: 1
    assert_select "main .mb-8 > h1", text: I18n.t("dashboard.show.title"), count: 1
    assert_select "main .my-8", count: 0
    assert_select "button[aria-label='Account menu'] .sidebar-account-label", text: users(:one).name, count: 1
    assert_select "button[aria-label='Account menu'] .sidebar-account-label", text: users(:one).email, count: 0
    # Home's icon: expanded sidebar, collapsed rail, and the mobile drawer nav.
    assert_select "a[href='#{user_root_path}'] svg[stroke-width='2']", count: 3
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

  test "privacy policy explains children's information, Google data, and service providers" do
    get privacy_path

    assert_response :success
    assert_select "h2", text: "Children's information"
    assert_select "h2", text: "Google user data"
    assert_select "h2", text: "Who we share information with"
    assert_select "h2", text: "Cookies"
    assert_select "h2", text: "Contact us"
    assert_includes response.body, "Stripe"
    assert_includes response.body, "Loops"
    assert_includes response.body, "Honeybadger"
    assert_includes response.body, "Render"
    assert_includes response.body, "Google API Services User Data Policy"
    assert_includes response.body, "Loops sends all of our account and billing emails, and marketing emails if you opt in."
    assert_includes response.body, "support@covehomeschool.com"
    assert_not_includes response.body, "Some suggestions to help create your Privacy Policy"
  end

  test "footer links to the refund policy" do
    get about_path
    assert_select "footer a[href='#{refunds_path}']", text: "Refunds"

    sign_in users(:one)
    get user_root_path
    assert_select "a[href='#{refunds_path}']"
  end
end
