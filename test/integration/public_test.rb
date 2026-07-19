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
end
