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

    test "links a verified Google identity to an existing user" do
      existing_user = users(:one)
      OmniAuth.config.add_mock(:google_oauth2, uid: "new-google-identity", info: {email: existing_user.email.upcase, name: "Google User"}, credentials: {token: "mock-token"})

      assert_no_difference "User.count" do
        assert_difference "ConnectedAccount.count", 1 do
          get "/users/auth/google_oauth2/callback"
        end
      end

      assert_equal existing_user, controller.current_user
      assert_equal accounts(:company), existing_user.family
    end

    test "refuses to link a Google identity when the matched user already has a different Google UID connected" do
      existing_user = users(:one)
      existing_user.connected_accounts.create!(provider: "google_oauth2", uid: "already-linked-uid", access_token: "token")
      OmniAuth.config.add_mock(:google_oauth2, uid: "new-uid", info: {email: existing_user.email, name: "Google User"}, credentials: {token: "mock-token"})

      assert_no_difference ["User.count", "ConnectedAccount.count"] do
        get "/users/auth/google_oauth2/callback"
      end

      assert_nil controller.current_user
      assert_equal I18n.t("users.omniauth_callbacks.account_exists"), flash[:alert]
    end

    test "does not link an unverified or missing Google email to an existing user" do
      OmniAuth.config.add_mock(:google_oauth2, uid: "no-email-uid", info: {email: "", name: "Google User"}, credentials: {token: "mock-token"})

      assert_no_difference ["User.count", "ConnectedAccount.count"] do
        get "/users/auth/google_oauth2/callback"
      end

      assert_nil controller.current_user
    end

    test "renders the Google sign-in button on sign in and sign up" do
      button_text = I18n.t("oauth.sign_in_with", provider: I18n.t("oauth.google_oauth2"))

      get "/users/sign_in"
      assert_includes response.body, button_text

      get "/users/sign_up"
      assert_includes response.body, button_text
    end

    test "shows Terms and Privacy Policy disclosure with the Google OAuth button" do
      ["/users/sign_in", "/users/sign_up"].each do |path|
        get path

        assert_select "p", text: "By continuing, you agree to the Terms and Privacy Policy."
        assert_select "a[href='#{terms_path}'][target='_blank']", text: "Terms"
        assert_select "a[href='#{privacy_path}'][target='_blank']", text: "Privacy Policy"
      end
    end
  end
end
