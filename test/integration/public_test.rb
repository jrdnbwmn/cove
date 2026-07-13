require "test_helper"

class Jumpstart::PublicTest < ActionDispatch::IntegrationTest
  test "homepage" do
    get root_path
    assert_response :success
  end

  test "dashboard" do
    sign_in users(:one)
    get root_path
    assert_response :success
  end
end
