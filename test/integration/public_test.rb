require "test_helper"

class Jumpstart::PublicTest < ActionDispatch::IntegrationTest
  test "homepage" do
    get root_path
    assert_response :success
    assert_not_includes response.body, 'data-controller="theme'
    assert_not_includes response.body, "data-theme-preference-value"
    assert_not_includes response.body, 'classList.toggle("dark"'
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
