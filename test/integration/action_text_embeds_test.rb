require "test_helper"

class ActionTextEmbedsTest < ActionDispatch::IntegrationTest
  test "signed-out visitor cannot create embeds" do
    request = stub_request(:get, /youtube\.com/)

    assert_no_difference "ActionText::Embed.count" do
      post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")
    end

    assert_redirected_to new_user_session_path
    assert_not_requested request
  end

  test "signed-in user gets an embed" do
    sign_in users(:one)
    stub_request(:get, "https://www.youtube.com/oembed?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dx")
      .to_return(status: 200, body: {title: "A video", type: "video", html: "<iframe></iframe>"}.to_json)

    post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")

    assert_response :success
    assert response.parsed_body["sgid"]
  end

  test "a slow oEmbed provider returns not found instead of hanging" do
    sign_in users(:one)
    stub_request(:get, /youtube\.com/).to_timeout

    post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")

    assert_response :not_found
  end

  test "an unreachable oEmbed provider returns not found instead of an error" do
    sign_in users(:one)

    [SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].each do |error|
      stub_request(:get, /youtube\.com/).to_raise(error)

      post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")

      assert_response :not_found
    end
  end

  test "embed rate limits are tracked per signed-in user" do
    sign_in users(:one)
    keys = []

    ActionText::EmbedsController.cache_store.stub(:increment, ->(key, *) {
      keys << key
      1
    }) do
      stub_request(:get, /youtube\.com/).to_return(status: 200, body: "{}")
      post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")
    end

    assert keys.first.end_with?(":#{users(:one).id}")
  end

  test "embed requests are rate limited" do
    sign_in users(:one)

    ActionText::EmbedsController.cache_store.stub(:increment, 21) do
      post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")
    end

    assert_response :too_many_requests
  end
end
