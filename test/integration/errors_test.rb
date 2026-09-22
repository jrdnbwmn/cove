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
    assert_wordmark_header response.body
    assert_includes response.body, %(href="#{root_path}")
    assert_not_includes response.body, 'type="importmap"'
  end

  test "renders the internal server error page" do
    response = error_response_for("/500")

    assert_equal 500, response.status
    assert_includes response.body, "Something went wrong"
    assert_wordmark_header response.body
    assert_includes response.body, %(href="#{root_path}")
    assert_not_includes response.body, 'type="importmap"'
  end

  test "minimal layout shows the Cove logo" do
    get new_user_session_path

    assert_response :success
    assert_select "nav.minimal-top-nav a[href=?] svg", root_path, count: 1
    assert_select "nav.minimal-top-nav a[href=?] .sr-only", root_path, text: "Cove"
  end

  private

  def assert_wordmark_header(body)
    header = Nokogiri::HTML(body).at_css("header a[href='#{root_path}']")
    assert_equal "Cove", header.at_css(".sr-only")&.text&.strip
    assert header.at_css("svg"), "expected the header logo link to contain an svg"
  end

  def error_response_for(path)
    session = ActionDispatch::Integration::Session.new(Rails.application.routes)
    session.get(path)
    session.response
  end
end
