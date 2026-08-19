require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "user can request and reset a password with a valid token" do
    user = users(:one)

    post user_password_path, params: {user: {email: user.email}}

    assert_response :redirect
    assert user.reload.reset_password_sent_at.present?

    reset_password_token = user.send(:set_reset_password_token)

    put user_password_path, params: {user: {
      reset_password_token: reset_password_token,
      password: "new-password",
      password_confirmation: "new-password"
    }}

    assert_response :redirect
    assert user.reload.valid_password?("new-password")
  end

  test "password reset form does not display boolean placeholder text" do
    user = users(:one)
    reset_password_token = user.send(:set_reset_password_token)

    get edit_user_password_path(reset_password_token: reset_password_token)

    assert_response :success
    assert_select "input#user_password[placeholder='true']", count: 0
    assert_select "input#user_password_confirmation[placeholder='true']", count: 0
  end

  test "requesting a password reset sends exactly one Loops reset-password request with the expected payload" do
    user = users(:one)

    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including(
        "transactionalId" => "cmsdnzduk02k40jx72rv3uwe2",
        "email" => user.email
      ))
      .to_return(status: 200, body: {success: true}.to_json)

    with_loops_delivery do
      post user_password_path, params: {user: {email: user.email}}
    end

    assert_response :redirect
    assert_requested stub, times: 1
  end

  test "the reset request's Loops payload carries the real edit-password route and the expected idempotency key" do
    user = users(:one)
    captured_request = nil

    stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with do |request|
        captured_request = request
        true
      end
      .to_return(status: 200, body: {success: true}.to_json)

    with_loops_delivery do
      post user_password_path, params: {user: {email: user.email}}
    end

    body = JSON.parse(captured_request.body)
    data_variables = body["dataVariables"]
    reset_password_url = data_variables["reset_password_url"]

    uri = URI.parse(reset_password_url)
    recognized = Rails.application.routes.recognize_path(uri.path, method: :get)
    assert_equal "users/passwords", recognized[:controller]
    assert_equal "edit", recognized[:action]

    raw_token = Rack::Utils.parse_nested_query(uri.query)["reset_password_token"]
    assert_not_nil raw_token

    expected_key = LoopsClient.client.idempotency_key(
      "cmsdnzduk02k40jx72rv3uwe2", user.email, data_variables
    )
    assert_equal expected_key, captured_request.headers["Idempotency-Key"]
  end

  test "completing a reset with the mailed token sends exactly one password-changed request, preserving the two-email flow" do
    user = users(:one)
    reset_requests = 0
    password_change_requests = 0
    captured_reset_request = nil
    captured_password_change_request = nil

    stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("transactionalId" => "cmsdnzduk02k40jx72rv3uwe2"))
      .to_return do |request|
        reset_requests += 1
        captured_reset_request = request
        {status: 200, body: {success: true}.to_json}
      end

    stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including("transactionalId" => "cmsdo8ixv001e0j1zu027i3s7"))
      .to_return do |request|
        password_change_requests += 1
        captured_password_change_request = request
        {status: 200, body: {success: true}.to_json}
      end

    with_loops_delivery do
      post user_password_path, params: {user: {email: user.email}}
    end

    assert_equal 1, reset_requests

    body = JSON.parse(captured_reset_request.body)
    reset_password_url = body["dataVariables"]["reset_password_url"]
    uri = URI.parse(reset_password_url)
    raw_token = Rack::Utils.parse_nested_query(uri.query)["reset_password_token"]

    with_loops_delivery do
      put user_password_path, params: {user: {
        reset_password_token: raw_token,
        password: "new-password",
        password_confirmation: "new-password"
      }}
    end

    assert_response :redirect
    assert user.reload.valid_password?("new-password")
    assert_equal 1, reset_requests
    assert_equal 1, password_change_requests

    password_change_data_variables = JSON.parse(captured_password_change_request.body)["dataVariables"]
    expected_password_change_key = LoopsClient.client.idempotency_key(
      "cmsdo8ixv001e0j1zu027i3s7", user.email, password_change_data_variables
    )
    assert_equal expected_password_change_key, captured_password_change_request.headers["Idempotency-Key"]
  end

  test "a Loops rate limit during a reset request propagates" do
    user = users(:one)

    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 429)

    assert_raises(LoopsClient::RateLimit) do
      with_loops_delivery do
        post user_password_path, params: {user: {email: user.email}}
      end
    end
  end

  private

  def with_loops_delivery
    original_delivery_method = LoopsDeviseMailer.delivery_method
    LoopsDeviseMailer.delivery_method = :loops
    yield
  ensure
    LoopsDeviseMailer.delivery_method = original_delivery_method
  end
end
