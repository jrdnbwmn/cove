require "test_helper"
require_relative "../support/stripe_schedule_helper"

class Jumpstart::AccountsTest < ActionDispatch::IntegrationTest
  include StripeScheduleHelper

  test "removed collection and switching routes are unroutable" do
    sign_in users(:one)
    get "/accounts/new"
    assert_response :not_found
    post "/accounts"
    assert_response :not_found
    patch "/accounts/#{accounts(:company).id}/switch"
    assert_response :not_found
  end

  test "only the owner can delete a family" do
    sign_in users(:two)

    assert_no_difference "Account.count" do
      delete account_path(accounts(:company))
    end
  end

  test "the owner can delete their family" do
    sign_in users(:noaccount)

    assert_difference "Account.count", -1 do
      delete account_path(accounts(:one))
    end

    assert_redirected_to root_path
  end

  test "a family owner sees a calm error if billing can't be canceled during deletion" do
    account = accounts(:one)
    stripe_api_key!
    subscription = stripe_subscription_for(account, plan: plans(:premium_yearly))
    stub_request(:delete, %r{https://api\.stripe\.com/v1/subscriptions/#{subscription.processor_id}})
      .to_return(status: 500, body: {error: {message: "Stripe is unavailable"}}.to_json)

    sign_in users(:noaccount)

    delete account_path(account)

    assert_redirected_to edit_account_path(account)
    assert_equal I18n.t("accounts.destroy.failure"), flash[:alert]
    assert Account.exists?(account.id)
  end

  test "a parent cannot update complimentary Premium fields" do
    account = accounts(:one)
    account.update!(complimentary_premium: false, complimentary_premium_note: nil)
    sign_in users(:noaccount)

    patch account_path(account), params: {
      account: {complimentary_premium: "1", complimentary_premium_note: "Attempted parent change"}
    }

    assert_response :bad_request
    assert_not_predicate account.reload, :complimentary_premium?
    assert_nil account.complimentary_premium_note
  end

  test "family settings page checks admin status once" do
    account = accounts(:one)
    account.account_invitations.create!(name: "Pending Parent", email: "pending@example.com", invited_by: users(:noaccount))
    account_user_queries = []

    sign_in users(:noaccount)

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_event, _started, _finished, _id, payload|
      account_user_queries << payload[:sql] if payload[:sql].match?(/FROM "account_users"/i)
    end

    get account_path(account)

    assert_response :success
    assert_operator account_user_queries.count, :<=, 2
    assert_select "a[href='#{edit_account_path(account)}']", text: I18n.t("accounts.show.edit_account")
    assert_select "table", count: 0
    assert_select "[data-family-row]", count: 2
    assert_select "[data-family-row]", text: /Owner/
    assert_select "a[href='#{new_account_account_invitation_path(account)}']", text: "Invite a parent"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
