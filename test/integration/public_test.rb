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
