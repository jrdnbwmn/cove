require "test_helper"

if defined? OmniAuth
  class Jumpstart::OmniauthCallbacksTest < ActionDispatch::IntegrationTest
    setup do
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(:developer, uid: "12345", info: {email: "twitter@example.com"}, credentials: {token: 1, expires_in: 100})
    end

    test "can register and login with a social account" do
      freeze_time
      assert_enqueued_jobs 1, only: LoopsMailDeliveryJob do
        assert_enqueued_email_with UserMailer, :account_created,
          params: ->(params) { params[:user].email == "twitter@example.com" } do
          assert_difference "User.count", 1 do
            get "/users/auth/developer/callback"
          end
        end
      end

      user = User.last
      assert_equal "twitter@example.com", user.email
      assert_equal "developer", user.connected_accounts.last.provider
      assert_equal "12345", user.connected_accounts.last.uid
      assert_equal user, controller.current_user
      assert_equal Time.now.utc + 100, user.connected_accounts.last.expires_at.utc
      assert_predicate user, :signup_completion_required?

      sign_out user
      get "/"

      assert_nil controller.current_user
      clear_enqueued_jobs
      assert_no_enqueued_jobs only: LoopsMailDeliveryJob do
        assert_no_difference "User.count" do
          get "/users/auth/developer/callback"
        end
      end

      assert_equal user, controller.current_user
    end

    test "does not flag a returning connected user" do
      user = users(:one)
      OmniAuth.config.add_mock(:developer, uid: "one", info: {email: user.email}, credentials: {token: 1})

      get "/users/auth/developer/callback"

      assert_equal user, controller.current_user
      assert_not_predicate user.reload, :signup_completion_required?
    end

    test "can connect a social account when signed in" do
      user = users(:one)

      sign_in user
      get "/users/auth/developer/callback"

      assert_equal "developer", user.connected_accounts.developer.last.provider
      assert_equal "12345", user.connected_accounts.developer.last.uid
      assert_not_predicate user.reload, :signup_completion_required?
    end

    test "cannot login with social if email is taken but not connected yet" do
      user = users(:one)
      user.connected_accounts.delete_all

      OmniAuth.config.add_mock(:developer, uid: "12345", info: {email: user.email}, credentials: {token: 1})

      get "/users/auth/developer/callback"

      assert user.connected_accounts.developer.none?
      assert_equal I18n.t("users.omniauth_callbacks.account_exists"), flash[:alert]
    end

    test "can connect a social account with another model" do
      user = users(:one)
      account = user.family

      sign_in user
      post "/users/auth/developer?record=#{account.to_sgid(for: :oauth, expires_in: 1.hour)}"

      assert_difference "ConnectedAccount.count" do
        get "/users/auth/developer/callback"
      end

      assert_equal account, ConnectedAccount.last.owner
    end

    test "cannot connect with account if connected to another user" do
      connected_account = connected_accounts(:one)
      user = users(:invited)

      # Ensure these are separate users
      assert_not_equal connected_account.owner, user

      sign_in user
      OmniAuth.config.add_mock(:developer, uid: connected_account.uid, info: {email: connected_account.owner.email}, credentials: {token: 1})
      get "/users/auth/developer/callback"

      assert user.connected_accounts.developer.none?
      assert_equal I18n.t("users.omniauth_callbacks.connected_to_another_account"), flash[:alert]
    end

    test "uses the email local part when OAuth sends no name data" do
      OmniAuth.config.add_mock(:developer, uid: "missing-name", info: {email: "family@example.com", name: "", first_name: nil, last_name: nil}, credentials: {token: 1})

      get "/users/auth/developer/callback"

      user = User.find_by!(email: "family@example.com")
      assert_equal "family", user.name
      assert_predicate user, :signup_completion_required?
    end
  end
end
