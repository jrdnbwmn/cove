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

  test "renders the not found page" do
    response = error_response_for("/404")

    assert_equal 404, response.status
    assert_includes response.body, "Page not found"
    assert_includes response.body, %(href="#{root_path}")
    assert_not_includes response.body, 'type="importmap"'
  end

  test "renders the internal server error page" do
    response = error_response_for("/500")

    assert_equal 500, response.status
    assert_includes response.body, "Something went wrong"
    assert_includes response.body, %(href="#{root_path}")
    assert_not_includes response.body, 'type="importmap"'
  end

  private

  def error_response_for(path)
    session = ActionDispatch::Integration::Session.new(Rails.application.routes)
    session.get(path)
    session.response
  end
end
