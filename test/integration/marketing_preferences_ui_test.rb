require "test_helper"

class MarketingPreferencesUiTest < ActionDispatch::IntegrationTest
  test "renders a dedicated marketing preferences form between profile and account deletion" do
    sign_in users(:one)

    get edit_user_registration_path

    assert_response :success
    assert_select "h2", text: "Marketing preferences", count: 1
    assert_select "form[action='#{marketing_preference_path}'][method='post']", count: 1 do
      assert_select "input[name='_method'][value='patch']", count: 1
      assert_select "input[type=hidden][name='marketing_preference[subscribed]'][value='0']", count: 1
      assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][value='1']", count: 1
      assert_select "input[name^='user[']", count: 0
      assert_select "button[type=submit] .when-enabled", text: "Save marketing preferences", count: 1
    end
    assert_select "form[action='/users'] input[name='marketing_preference[subscribed]']", count: 0
    assert_includes response.body, "Cove updates"
    assert_includes response.body, "Receive occasional product news and homeschooling resources by email."

    profile_form_index = response.body.index('action="/users"')
    marketing_heading_index = response.body.index("Marketing preferences")
    delete_heading_index = response.body.index("Delete my account")
    marketing_form_index = response.body.index('action="/marketing_preference"')
    hidden_index = response.body.index('name="marketing_preference[subscribed]"')
    switch_index = response.body.index('name="marketing_preference[subscribed]"', hidden_index + 1)

    assert_operator profile_form_index, :<, marketing_heading_index
    assert_operator marketing_heading_index, :<, marketing_form_index
    assert_operator marketing_form_index, :<, delete_heading_index
    assert_operator hidden_index, :<, switch_index
  end

  test "renders an unchecked enabled switch for a never-subscribed user" do
    sign_in users(:one)

    get edit_user_registration_path

    assert_response :success
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]']", count: 1
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][checked]", count: 0
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][disabled]", count: 0
    assert_select "form[action='#{marketing_preference_path}'] button[type=submit]", count: 1
    assert_select "form[action='#{marketing_preference_path}'] button[type=submit][disabled]", count: 0
  end

  test "renders a checked enabled switch for a subscribed user" do
    sign_in users(:marketing_subscribed)

    get edit_user_registration_path

    assert_response :success
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]']", count: 1
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][checked]", count: 1
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][disabled]", count: 0
    assert_select "form[action='#{marketing_preference_path}'] button[type=submit]", count: 1
    assert_select "form[action='#{marketing_preference_path}'] button[type=submit][disabled]", count: 0
  end

  test "keeps a user app opt-out enabled for deliberate reversal" do
    sign_in users(:marketing_unsubscribed)

    get edit_user_registration_path

    assert_response :success
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]']", count: 1
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][checked]", count: 0
    assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][disabled]", count: 0
    assert_select "form[action='#{marketing_preference_path}'] button[type=submit]", count: 1
    assert_select "form[action='#{marketing_preference_path}'] button[type=submit][disabled]", count: 0
  end

  {
    "user_loops" => "You unsubscribed through email preferences. You can't currently restore this subscription from Cove.",
    "mailing_list_unsubscribe" => "You unsubscribed through email preferences. You can't currently restore this subscription from Cove.",
    "hard_bounce" => "We couldn't deliver email to this address. Update your email before subscribing again.",
    "spam_report" => "Marketing updates are unavailable because a previous message was reported as spam."
  }.each do |reason, message|
    test "disables marketing controls for a #{reason} opt-out" do
      user = users(:marketing_unsubscribed)
      user.update!(marketing_opt_out_reason: reason)
      sign_in user

      get edit_user_registration_path

      assert_response :success
      assert_select "input[type=checkbox][name='marketing_preference[subscribed]'][disabled]", count: 1
      assert_select "form[action='#{marketing_preference_path}'] button[type=submit][disabled]", count: 1
      assert_select "p", text: message, count: 1
    end
  end
end
