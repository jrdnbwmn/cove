require "test_helper"
require "ostruct"

class LoopsWebhookEventProcessorTest < ActiveSupport::TestCase
  LIST_ID = "cmsdo8ncl02wc0j0j4rxwhy4l"

  def config(list_id: LIST_ID)
    OpenStruct.new(contact_sync_mailing_list_id: list_id)
  end

  def processor(list_id: LIST_ID)
    LoopsWebhookEventProcessor.new(config: config(list_id: list_id))
  end

  def event(user, event_name, payload: {}, event_time: nil, mailing_list_id: nil)
    full_payload = {"eventName" => event_name, "contactIdentity" => {"userId" => user&.id&.to_s, "email" => user&.email}}
    full_payload["mailingList"] = {"id" => mailing_list_id} if mailing_list_id
    full_payload.merge!(payload)

    LoopsWebhookEvent.create!(
      webhook_id: "wh_#{SecureRandom.hex(4)}",
      event_name: event_name,
      event_time: event_time,
      payload: full_payload
    )
  end

  test "contact.unsubscribed records a user_loops opt-out" do
    user = users(:marketing_subscribed)
    processor.call(event(user, "contact.unsubscribed"))

    assert_equal "user_loops", user.reload.marketing_opt_out_reason
  end

  test "email.unsubscribed records a user_loops opt-out" do
    user = users(:marketing_subscribed)
    processor.call(event(user, "email.unsubscribed"))

    assert_equal "user_loops", user.reload.marketing_opt_out_reason
  end

  test "email.spamReported records a spam_report opt-out" do
    user = users(:marketing_subscribed)
    processor.call(event(user, "email.spamReported"))

    assert_equal "spam_report", user.reload.marketing_opt_out_reason
  end

  test "email.hardBounced records a hard_bounce opt-out" do
    user = users(:marketing_subscribed)
    processor.call(event(user, "email.hardBounced"))

    assert_equal "hard_bounce", user.reload.marketing_opt_out_reason
  end

  test "contact.mailingList.unsubscribed for the Cove list records mailing_list_unsubscribe" do
    user = users(:marketing_subscribed)
    processor.call(event(user, "contact.mailingList.unsubscribed", mailing_list_id: LIST_ID))

    assert_equal "mailing_list_unsubscribe", user.reload.marketing_opt_out_reason
  end

  test "contact.mailingList.unsubscribed for a non-Cove list changes nothing" do
    user = users(:marketing_subscribed)
    processor.call(event(user, "contact.mailingList.unsubscribed", mailing_list_id: "some_other_list"))

    assert_nil user.reload.marketing_opt_out_reason
  end

  test "email.resubscribed grants marketing consent from loops" do
    user = users(:marketing_unsubscribed)
    user.update!(marketing_opt_out_reason: "user_loops")

    processor.call(event(user, "email.resubscribed"))

    user.reload
    assert_predicate user, :marketing_subscribed?
    assert_equal "loops", user.marketing_opt_in_source
  end

  test "email.resubscribed for a spam_report user leaves state alone" do
    user = users(:marketing_unsubscribed)
    user.update!(marketing_opt_out_reason: "spam_report")

    processor.call(event(user, "email.resubscribed"))

    user.reload
    assert_not_predicate user, :marketing_subscribed?
    assert_equal "spam_report", user.marketing_opt_out_reason
  end

  test "unknown userId and unknown email is a silent no-op" do
    assert_nothing_raised do
      processor.call(event(nil, "contact.unsubscribed", payload: {"contactIdentity" => {"userId" => "999999", "email" => "nobody@example.com"}}))
    end
  end

  test "email fallback resolves a user when userId is null" do
    user = users(:marketing_subscribed)
    e = event(user, "contact.unsubscribed", payload: {"contactIdentity" => {"userId" => nil, "email" => user.email}})

    processor.call(e)

    assert_equal "user_loops", user.reload.marketing_opt_out_reason
  end

  test "testing.testEvent is a no-op" do
    user = users(:marketing_subscribed)
    assert_nothing_raised { processor.call(event(user, "testing.testEvent")) }
    assert_nil user.reload.marketing_opt_out_reason
  end

  test "email.opened is a no-op" do
    user = users(:marketing_subscribed)
    assert_nothing_raised { processor.call(event(user, "email.opened")) }
    assert_nil user.reload.marketing_opt_out_reason
  end

  test "stale opt-out before marketing_opt_in_at is ignored" do
    user = users(:marketing_subscribed)
    stale_time = user.marketing_opt_in_at - 1.day

    processor.call(event(user, "contact.unsubscribed", event_time: stale_time))

    assert_nil user.reload.marketing_opt_out_reason
  end

  test "stale resubscribe before marketing_opt_out_at is ignored" do
    user = users(:marketing_unsubscribed)
    user.update!(marketing_opt_out_reason: "user_loops")
    stale_time = user.marketing_opt_out_at - 1.day

    processor.call(event(user, "email.resubscribed", event_time: stale_time))

    user.reload
    assert_not_predicate user, :marketing_subscribed?
    assert_equal "user_loops", user.marketing_opt_out_reason
  end
end
