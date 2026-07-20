require "test_helper"

class ErrorsTest < ActionDispatch::IntegrationTest
  test "returns a JSON not found error" do
    get "/404.json"

    assert_response :not_found
    assert_equal({"error" => "Not found"}, response.parsed_body)
  end

  test "returns a JSON internal server error" do
    get "/500.json"

    assert_response :internal_server_error
    assert_equal({"error" => "Internal server error"}, response.parsed_body)
  end

  test "does not treat other numeric paths as error routes" do
    get "/999999"

    assert_redirected_to root_path
  end
end
