require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include InvisibleCaptcha

  setup do
    @user_params = {user:
                        {name: "Test User",
                         email: "user@test.com",
                         password: "TestPassword",
                         terms_of_service: "1"}}

    # With this feature enabled, we also need to submit an account
    if Jumpstart.config.register_with_account?
      @user_params[:user][:owned_accounts_attributes] = [{name: "Test Account"}]
    end
  end

  class ThemePickerTest < Users::RegistrationsControllerTest
    test "edit registration does not render a theme picker" do
      sign_in users(:one)

      get edit_user_registration_path

      assert_response :success
      assert_not_includes response.body, 'name="user[theme]"'
    end
  end

  class BasicRegistrationTest < Users::RegistrationsControllerTest
    test "successfully registration form render" do
      get new_user_registration_path
      assert_response :success
      assert_includes response.body, "user[name]"
      assert_includes response.body, "user[email]"
      assert_includes response.body, "user[password]"
      assert_includes response.body, InvisibleCaptcha.sentence_for_humans
    end

    test "registration form renders an unchecked marketing consent field after terms" do
      get new_user_registration_path

      assert_response :success
      assert_select "input[type=hidden][name='user[marketing_opt_in]'][value='0']", 1
      assert_select "input[type=checkbox][name='user[marketing_opt_in]'][value='1']", 1
      assert_select "input[type=checkbox][name='user[marketing_opt_in]'][checked]", 0
      assert_includes response.body, "Send me occasional Cove updates and homeschooling resources."

      terms_index = response.body.index('name="user[terms_of_service]"')
      hidden_index = response.body.index('name="user[marketing_opt_in]"')
      checkbox_index = response.body.index('name="user[marketing_opt_in]"', hidden_index + 1)
      submit_index = response.body.index('type="submit"')

      assert_operator terms_index, :<, hidden_index
      assert_operator hidden_index, :<, checkbox_index
      assert_operator checkbox_index, :<, submit_index
    end

    test "failed registration preserves checked marketing consent" do
      invalid_params = @user_params.deep_merge(user: {email: "", marketing_opt_in: "1"})

      assert_no_difference "User.count" do
        post user_registration_url, params: invalid_params
      end

      assert_response :unprocessable_entity
      assert_select "input[type=checkbox][name='user[marketing_opt_in]'][checked]", 1
    end

    test "invitation registration does not render marketing consent inputs" do
      invitation = account_invitations(:one)

      get new_user_registration_path(invite: invitation.token)

      assert_response :success
      assert_select "input[name='user[marketing_opt_in]']", 0
    end

    test "successful user registration" do
      assert_difference "User.count" do
        post user_registration_url, params: @user_params
      end
    end

    test "checked registration records marketing consent" do
      assert_difference "User.count" do
        post user_registration_url, params: @user_params.deep_merge(user: {marketing_opt_in: "1"})
      end

      user = User.find_by!(email: @user_params[:user][:email])
      assert_predicate user, :marketing_subscribed?
      assert_equal "registration", user.marketing_opt_in_source
    end

    test "unchecked registration leaves marketing consent empty" do
      assert_difference "User.count" do
        post user_registration_url, params: @user_params.deep_merge(user: {marketing_opt_in: "0"})
      end

      user = User.find_by!(email: @user_params[:user][:email])
      assert_nil user.marketing_opt_in_at
      assert_nil user.marketing_opt_in_source
      assert_nil user.marketing_opt_out_at
      assert_nil user.marketing_opt_out_reason
    end

    test "invitation registration ignores a crafted marketing consent parameter" do
      invitation = account_invitations(:one)
      invitation_params = @user_params.deep_merge(
        invite: invitation.token,
        user: {email: "new-invited@example.com", marketing_opt_in: "1"}
      )

      assert_difference "User.count" do
        post user_registration_url, params: invitation_params
      end

      user = User.find_by!(email: "new-invited@example.com")
      assert_nil user.marketing_opt_in_at
      assert_nil user.marketing_opt_in_source
    end

    test "profile updates cannot change marketing consent" do
      sign_in users(:one)

      patch user_registration_url, params: {user: {marketing_opt_in: "1"}}

      user = users(:one).reload
      assert_nil user.marketing_opt_in_at
      assert_nil user.marketing_opt_in_source
    end

    test "failed user registration" do
      assert_no_difference "User.count" do
        post user_registration_url, params: {}
      end
    end
  end

  class InvibleCaptchaTest < Users::RegistrationsControllerTest
    test "honeypot is not filled and user creation succeeds" do
      assert_difference "User.count" do
        post user_registration_url, params: @user_params.merge(honeypotx: "")
      end
    end

    test "honeypot is filled and user creation fails" do
      assert_no_difference "User.count" do
        post user_registration_url, params: @user_params.merge(honeypotx: "spam")
      end
    end
  end
end
