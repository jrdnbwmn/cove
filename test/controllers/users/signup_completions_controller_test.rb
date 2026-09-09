require "test_helper"

class Users::SignupCompletionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "requires authentication" do
    get signup_completion_path

    assert_redirected_to new_user_session_path
  end

  test "redirects stale visits to the home page" do
    sign_in users(:one)

    get signup_completion_path

    assert_redirected_to root_path
  end

  test "renders the pending user's email and completion form" do
    user = users(:oauth_signup_pending)
    sign_in user

    get signup_completion_path

    assert_response :success
    assert_includes response.body, user.email
    assert_select "input[name='user[first_name]'][value='OAuth']", 1
    assert_select "input[name='user[last_name]'][value='Pending']", 1
    assert_select "input[type=hidden][name='user[marketing_opt_in]'][value='0']", 1
    assert_select "input[type=checkbox][name='user[marketing_opt_in]'][value='1']", 1
    assert_select "a[href='#{privacy_path}'][target='_blank']", 1
    assert_select "button[type=submit]", 1
  end

  test "renders the checkbox checked when the user already opted in via settings" do
    user = users(:oauth_signup_pending)
    user.grant_marketing_consent(source: "settings")
    sign_in user

    get signup_completion_path

    assert_select "input[type=checkbox][name='user[marketing_opt_in]'][checked]", 1
  end

  test "keeps the checkbox checked and returns 422 when first name is blank" do
    user = users(:oauth_signup_pending)
    sign_in user

    patch signup_completion_path, params: {user: {first_name: "", last_name: "Updated", marketing_opt_in: "1"}}

    assert_response :unprocessable_entity
    assert_predicate user.reload, :signup_completion_required?
    assert_select "input[type=checkbox][name='user[marketing_opt_in]'][checked]", 1
    assert_includes response.body, "First name can't be blank"
  end

  test "completes signup, records registration consent, and queues a contact sync when checked" do
    user = users(:oauth_signup_pending)
    sign_in user

    patch signup_completion_path, params: {user: {first_name: "Updated", last_name: "Name", marketing_opt_in: "1"}}
    user.reload
    assert_redirected_to root_path
    assert_equal "Updated", user.first_name
    assert_equal "Name", user.last_name
    assert_not_predicate user, :signup_completion_required?
    assert_predicate user, :marketing_subscribed?
    assert_equal "registration", user.marketing_opt_in_source
    assert_enqueued_with(job: LoopsContactSyncJob, args: [user.id, "opt_in"])
  end

  test "completes signup without consent or a contact sync when unchecked" do
    user = users(:oauth_signup_pending)
    sign_in user

    assert_no_enqueued_jobs only: LoopsContactSyncJob do
      patch signup_completion_path, params: {user: {first_name: "Updated", last_name: "Name", marketing_opt_in: "0"}}
    end

    user.reload
    assert_redirected_to root_path
    assert_not_predicate user, :signup_completion_required?
    assert_not_predicate user, :marketing_subscribed?
  end

  test "persists name changes when the user already opted in via settings before completing signup" do
    user = users(:oauth_signup_pending)
    user.grant_marketing_consent(source: "settings")
    sign_in user

    patch signup_completion_path, params: {user: {first_name: "Updated", last_name: "Name", marketing_opt_in: "1"}}

    user.reload
    assert_redirected_to root_path
    assert_equal "Updated", user.first_name
    assert_equal "Name", user.last_name
    assert_not_predicate user, :signup_completion_required?
  end

  test "redirects to the location stored by the signup completion gate" do
    user = users(:oauth_signup_pending)
    sign_in user

    get notifications_path
    assert_redirected_to signup_completion_path

    patch signup_completion_path, params: {user: {first_name: "Updated", last_name: "Name", marketing_opt_in: "0"}}

    assert_redirected_to notifications_path
  end

  test "redirects a duplicate submission to the home page without changing consent" do
    user = users(:oauth_signup_pending)
    user.update!(signup_completion_required: false)
    sign_in user

    patch signup_completion_path, params: {user: {first_name: "Changed", last_name: "Name", marketing_opt_in: "1"}}

    assert_redirected_to root_path
    assert_equal "OAuth", user.reload.first_name
    assert_not_predicate user, :marketing_subscribed?
  end
end
