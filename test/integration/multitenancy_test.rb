require "test_helper"

class Jumpstart::MultitenancyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @family = accounts(:company)
    sign_in @user
  end

  test "a stale cookie cannot select a different family" do
    cookies[:account_id] = accounts(:one).id

    get about_path

    assert_response :success
    assert_equal @family, @user.family
  end

  test "a signed-in user without a family receives one default family" do
    user = users(:noaccount)
    old_family = accounts(:one)
    old_family.account_users.destroy_all
    old_family.archive!
    sign_in user

    get about_path

    assert_response :success
    assert_not_nil user.family
    assert_equal "No Account User's Family", user.family.name
  end

  test "an archived family is never selected from the session" do
    @family.account_users.destroy_all
    @family.archive!

    get about_path

    assert_response :success
    assert_not_equal @family, @user.family
  end
end
