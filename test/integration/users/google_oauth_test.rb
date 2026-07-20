require "test_helper"

if defined? OmniAuth
  class Users::GoogleOauthTest < ActionDispatch::IntegrationTest
    setup do
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(:google_oauth2, uid: "111111", info: {email: "newgoogleuser@example.com", name: "Google User"}, credentials: {token: "mock-token"})
    end

    test "signs up a new user via Google" do
      assert_difference "User.count" do
        get "/users/auth/google_oauth2/callback"
      end

      user = User.last
      assert_equal "newgoogleuser@example.com", user.email
      assert_equal "Google User", user.name
      assert_equal "google_oauth2", user.connected_accounts.last.provider
      assert_equal "111111", user.connected_accounts.last.uid
      assert_equal user, controller.current_user
    end

    test "signs in a returning connected user without creating duplicates" do
      get "/users/auth/google_oauth2/callback"
      user = User.last

      sign_out user
      get "/"
      assert_nil controller.current_user

      assert_no_difference ["User.count", "ConnectedAccount.count"] do
        get "/users/auth/google_oauth2/callback"
      end

      assert_equal user, controller.current_user
    end

    test "renders the Google sign-in button on sign in and sign up" do
      button_text = I18n.t("oauth.sign_in_with", provider: I18n.t("oauth.google_oauth2"))

      get "/users/sign_in"
      assert_includes response.body, button_text

      get "/users/sign_up"
      assert_includes response.body, button_text
    end
  end
end
