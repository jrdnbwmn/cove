require "test_helper"

class AccountPasswordsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "user can change their password with the correct current password" do
    new_password = Devise.friendly_token

    patch account_password_path, params: {
      user: {
        current_password: UNIQUE_PASSWORD,
        password: new_password,
        password_confirmation: new_password
      }
    }

    assert_redirected_to account_password_path
    assert_equal I18n.t("account.passwords.updated"), flash[:notice]
    assert @user.reload.valid_password?(new_password)
    assert_not @user.valid_password?(UNIQUE_PASSWORD)
  end

  test "wrong current password re-renders edit with an error" do
    new_password = Devise.friendly_token

    patch account_password_path, params: {
      user: {
        current_password: "not-the-current-password",
        password: new_password,
        password_confirmation: new_password
      }
    }

    assert_response :unprocessable_content
    assert_select "li", /Current password/i
    assert_not @user.reload.valid_password?(new_password)
    assert @user.valid_password?(UNIQUE_PASSWORD)
  end

  test "mismatched password confirmation re-renders edit with an error" do
    new_password = Devise.friendly_token

    patch account_password_path, params: {
      user: {
        current_password: UNIQUE_PASSWORD,
        password: new_password,
        password_confirmation: "#{new_password}-mismatch"
      }
    }

    assert_response :unprocessable_content
    assert_select "li", /Password confirmation/i
    assert_not @user.reload.valid_password?(new_password)
    assert @user.valid_password?(UNIQUE_PASSWORD)
  end
end
