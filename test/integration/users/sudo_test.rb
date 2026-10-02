require "test_helper"

class SudoTest < ActionDispatch::IntegrationTest
  test "sudo password attempts are rate limited" do
    sign_in users(:one)

    Users::SudoController.cache_store.stub(:increment, 11) do
      post sudo_path, params: {password: UNIQUE_PASSWORD, redirect_to: root_url}
    end

    assert_redirected_to root_path
    assert_equal I18n.t("try_again_later"), flash[:alert]
  end
end
