require "test_helper"

class Jumpstart::ConfigTest < ActionDispatch::IntegrationTest
  test "can access jumpstart config" do
    get "/jumpstart"
    assert_response :success
  end

  test "Jumpstart configuration stays light for users with a saved dark preference" do
    user = users(:one)
    user.update!(preferences: {theme: "dark"})
    sign_in user

    get "/jumpstart"

    assert_response :success
    assert_not_includes response.body, '<html class="h-full antialiased dark"'
    assert_not_includes response.body, 'data-controller="theme"'
    assert_not_includes response.body, "data-theme-preference-value"
  end

  test "Jumpstart docs do not offer a dark theme switcher" do
    user = users(:one)
    user.update!(preferences: {theme: "dark"})
    sign_in user

    get "/jumpstart/docs"

    assert_response :success
    assert_not_includes response.body, '<html class="docs-layout h-full antialiased dark"'
    assert_not_includes response.body, 'id="theme-select"'
    assert_not_includes response.body, "classList.add(this.value)"
  end

  test "Jumpstart theme docs do not render dark examples" do
    get "/jumpstart/docs/themes"

    assert_response :success
    assert_includes response.body, "Cove uses a single, light-only theme."
    assert_not_includes response.body, '<div class="dark">'
  end
end
