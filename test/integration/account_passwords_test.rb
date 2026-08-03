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

  test "changing the password sends exactly one Loops password-changed request" do
    new_password = Devise.friendly_token
    captured_request = nil

    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including(
        "transactionalId" => "cmsdo8ixv001e0j1zu027i3s7",
        "email" => @user.email
      ))
      .to_return do |request|
        captured_request = request
        {status: 200, body: {success: true}.to_json}
      end

    with_loops_delivery do
      patch account_password_path, params: {
        user: {
          current_password: UNIQUE_PASSWORD,
          password: new_password,
          password_confirmation: new_password
        }
      }
    end

    assert_redirected_to account_password_path
    assert_requested stub, times: 1
    assert @user.reload.valid_password?(new_password)

    data_variables = JSON.parse(captured_request.body)["dataVariables"]
    expected_key = LoopsClient.client.idempotency_key(
      "cmsdo8ixv001e0j1zu027i3s7", @user.email, data_variables
    )
    assert_equal expected_key, captured_request.headers["Idempotency-Key"]
  end

  test "an unprocessable Loops password-changed delivery propagates and rolls back the password update" do
    new_password = Devise.friendly_token

    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 422)

    assert_raises(LoopsClient::UnprocessableContent) do
      with_loops_delivery do
        patch account_password_path, params: {
          user: {
            current_password: UNIQUE_PASSWORD,
            password: new_password,
            password_confirmation: new_password
          }
        }
      end
    end

    assert_not @user.reload.valid_password?(new_password)
    assert @user.valid_password?(UNIQUE_PASSWORD)
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
