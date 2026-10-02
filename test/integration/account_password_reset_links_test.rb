require "test_helper"

class AccountPasswordResetLinksTest < ActionDispatch::IntegrationTest
  test "signed-in user can email themselves a link to set a password" do
    user = users(:one)
    sign_in user

    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with(body: hash_including(
        "transactionalId" => "cmsdnzduk02k40jx72rv3uwe2",
        "email" => user.email
      ))
      .to_return(status: 200, body: {success: true}.to_json)

    with_loops_delivery do
      post account_password_reset_link_path
    end

    assert_redirected_to edit_account_password_path
    assert_equal I18n.t("account.password_reset_links.create.sent", email: user.email), flash[:notice]
    assert_requested stub, times: 1
    assert user.reload.reset_password_token.present?
  end

  test "signed-out visitor is sent to sign in" do
    post account_password_reset_link_path

    assert_redirected_to new_user_session_path
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
  end
end
