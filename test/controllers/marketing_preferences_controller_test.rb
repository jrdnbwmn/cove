require "test_helper"

class MarketingPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    patch marketing_preference_path, params: {marketing_preference: {subscribed: "1"}}

    assert_redirected_to new_user_session_path
  end

  test "routes the singular preference update" do
    assert_routing(
      {method: "patch", path: "/marketing_preference"},
      {controller: "marketing_preferences", action: "update"}
    )
  end

  test "updates only the current user's marketing consent" do
    sign_in users(:one)

    patch marketing_preference_path, params: {
      user_id: users(:two).id,
      marketing_preference: {subscribed: "1"}
    }

    assert_predicate users(:one).reload, :marketing_subscribed?
    assert_not_predicate users(:two).reload, :marketing_subscribed?
  end

  test "opts the current user into marketing from settings" do
    sign_in users(:one)

    patch marketing_preference_path, params: {marketing_preference: {subscribed: "1"}}

    user = users(:one).reload
    assert_redirected_to edit_user_registration_path
    assert_predicate user, :marketing_subscribed?
    assert_equal "settings", user.marketing_opt_in_source
  end

  test "opts the current user out of marketing from the app" do
    sign_in users(:marketing_subscribed)

    patch marketing_preference_path, params: {marketing_preference: {subscribed: "0"}}

    user = users(:marketing_subscribed).reload
    assert_redirected_to edit_user_registration_path
    assert_not_predicate user, :marketing_subscribed?
    assert_equal "user_app", user.marketing_opt_out_reason
  end

  test "preserves consent on no-op preference updates" do
    user = users(:marketing_subscribed)
    original_opt_in_at = user.marketing_opt_in_at
    sign_in user

    patch marketing_preference_path, params: {marketing_preference: {subscribed: "1"}}

    assert_equal original_opt_in_at, user.reload.marketing_opt_in_at
  end

  test "allows a user app opt-out to be reversed" do
    sign_in users(:marketing_unsubscribed)

    patch marketing_preference_path, params: {marketing_preference: {subscribed: "1"}}

    user = users(:marketing_unsubscribed).reload
    assert_predicate user, :marketing_subscribed?
    assert_equal "settings", user.marketing_opt_in_source
  end

  %w[user_loops mailing_list_unsubscribe hard_bounce spam_report].each do |reason|
    test "does not reverse a #{reason} opt-out" do
      user = users(:marketing_unsubscribed)
      user.update!(marketing_opt_out_reason: reason)
      sign_in user

      patch marketing_preference_path, params: {marketing_preference: {subscribed: "1"}}

      assert_not_predicate user.reload, :marketing_subscribed?
      assert_equal reason, user.marketing_opt_out_reason
    end
  end

  test "rejects missing and invalid subscription values" do
    user = users(:one)
    sign_in user

    patch marketing_preference_path
    assert_redirected_to edit_user_registration_path
    assert_nil user.reload.marketing_opt_in_at

    patch marketing_preference_path, params: {marketing_preference: {subscribed: "true"}}
    assert_redirected_to edit_user_registration_path
    assert_nil user.reload.marketing_opt_in_at
  end

  test "ignores forged marketing provenance" do
    sign_in users(:one)

    patch marketing_preference_path, params: {
      marketing_preference: {
        subscribed: "1",
        marketing_opt_in_source: "loops",
        marketing_opt_out_reason: "spam_report",
        marketing_opt_in_at: 1.year.ago.iso8601
      }
    }

    user = users(:one).reload
    assert_predicate user, :marketing_subscribed?
    assert_equal "settings", user.marketing_opt_in_source
    assert_nil user.marketing_opt_out_reason
  end
end
