require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "returns errors if invalid params submitted" do
    post api_v1_users_url, params: {}
    assert_response :unprocessable_content
    assert response.parsed_body["errors"]
    assert_equal [I18n.t("errors.messages.blank")], response.parsed_body["errors"]["email"]
  end

  test "returns user and api token on success" do
    email = "api-user@example.com"

    Jumpstart.config.stub(:register_with_account?, false) do
      assert_difference "User.count" do
        post api_v1_users_url, params: {user: {email: email, name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1"}}
        assert_response :success
      end
    end

    assert response.parsed_body["user"]
    assert_equal email, response.parsed_body.dig("user", "email")
    assert_not_nil response.parsed_body.dig("user", "api_tokens").first["token"]
  end

  test "turbo native registration" do
    Jumpstart.config.stub(:personal_accounts?, true) do
      Jumpstart.config.stub(:register_with_account?, false) do
        assert_difference "User.count" do
          post api_v1_users_url, params: {user: {email: "api-user@example.com", name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1"}}, headers: {HTTP_USER_AGENT: "Turbo Native iOS"}
          assert_response :success
        end
      end
    end

    user = User.last

    assert_equal "API User's Family", user.family.name

    # Set Devise cookies for Turbo Native apps
    assert_not_nil session["warden.user.user.key"]

    # Returns an API token
    assert_equal user.api_tokens.find_by(name: ApiToken::APP_NAME).token, response.parsed_body["token"]
  end

  test "registration creates one auto-named family with an owner admin" do
    Jumpstart.config.stub(:register_with_account?, true) do
      assert_difference ["Account.count", "AccountUser.count"], 1 do
        post api_v1_users_url, params: {user: {email: "api-user@example.com", name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1"}}, headers: {HTTP_USER_AGENT: "Turbo Native iOS"}
        assert_response :success
      end

      user = User.order(created_at: :asc).last
      family = user.family

      assert_equal "API User's Family", family.name
      assert_equal user, family.owner
      assert family.account_users.sole.admin?
    end
  end

  test "registration ignores crafted nested account attributes" do
    Jumpstart.config.stub(:register_with_account?, true) do
      assert_difference ["Account.count", "AccountUser.count"], 1 do
        post api_v1_users_url, params: {user: {email: "api-user@example.com", name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1", owned_accounts_attributes: [{name: "Crafted Family"}]}}, headers: {HTTP_USER_AGENT: "Turbo Native iOS"}
        assert_response :success
      end

      user = User.order(created_at: :asc).last
      assert_equal "API User's Family", user.family.name
      assert_equal 1, user.accounts.count
    end
  end
end
