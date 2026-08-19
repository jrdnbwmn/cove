require "test_helper"

class LoopsWebhookTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  COVE_MAILING_LIST_ID = "cmsdo8ncl02wc0j0j4rxwhy4l"

  setup { clear_enqueued_jobs }

  def receive_and_process(webhook_id:, body:)
    LoopsWebhookSignature.stub(:secret, LOOPS_WEBHOOK_TEST_SECRET) do
      assert_no_enqueued_jobs only: LoopsContactSyncJob do
        post_loops_webhook(webhook_id:, body:)
        assert_response :ok
        perform_enqueued_jobs only: LoopsWebhookEventJob
      end
    end
  end

  test "contact.unsubscribed records a user_loops opt-out and does not echo to Loops" do
    user = users(:marketing_subscribed)
    body = {
      "eventName" => "contact.unsubscribed",
      "eventTime" => 10.minutes.from_now.to_i,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    receive_and_process(webhook_id: "wh_contact_unsubscribed", body: body)

    user.reload
    assert_equal "user_loops", user.marketing_opt_out_reason
    assert user.marketing_opt_out_at.present?
    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_contact_unsubscribed")
    assert event.processed_at.present?
  end

  test "email.unsubscribed records a user_loops opt-out and does not echo to Loops" do
    user = users(:marketing_subscribed)
    body = {
      "eventName" => "email.unsubscribed",
      "eventTime" => 10.minutes.from_now.to_i,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    receive_and_process(webhook_id: "wh_email_unsubscribed", body: body)

    user.reload
    assert_equal "user_loops", user.marketing_opt_out_reason
    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_email_unsubscribed")
    assert event.processed_at.present?
  end

  test "email.spamReported records a spam_report opt-out and does not echo to Loops" do
    user = users(:marketing_subscribed)
    body = {
      "eventName" => "email.spamReported",
      "eventTime" => 10.minutes.from_now.to_i,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    receive_and_process(webhook_id: "wh_spam_reported", body: body)

    user.reload
    assert_equal "spam_report", user.marketing_opt_out_reason
    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_spam_reported")
    assert event.processed_at.present?
  end

  test "email.hardBounced records a hard_bounce opt-out and does not echo to Loops" do
    user = users(:marketing_subscribed)
    body = {
      "eventName" => "email.hardBounced",
      "eventTime" => 10.minutes.from_now.to_i,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    receive_and_process(webhook_id: "wh_hard_bounced", body: body)

    user.reload
    assert_equal "hard_bounce", user.marketing_opt_out_reason
    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_hard_bounced")
    assert event.processed_at.present?
  end

  test "contact.mailingList.unsubscribed for the Cove list records a mailing_list_unsubscribe opt-out and does not echo to Loops" do
    user = users(:marketing_subscribed)
    body = {
      "eventName" => "contact.mailingList.unsubscribed",
      "eventTime" => 10.minutes.from_now.to_i,
      "contactIdentity" => {"userId" => user.id.to_s},
      "mailingList" => {"id" => COVE_MAILING_LIST_ID}
    }.to_json

    receive_and_process(webhook_id: "wh_mailing_list_unsubscribed", body: body)

    user.reload
    assert_equal "mailing_list_unsubscribe", user.marketing_opt_out_reason
    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_mailing_list_unsubscribed")
    assert event.processed_at.present?
  end

  test "email.resubscribed grants loops-sourced consent and does not echo to Loops" do
    user = users(:marketing_unsubscribed)
    body = {
      "eventName" => "email.resubscribed",
      "eventTime" => 10.minutes.from_now.to_i,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    receive_and_process(webhook_id: "wh_resubscribed", body: body)

    user.reload
    assert user.marketing_subscribed?
    assert_equal "loops", user.marketing_opt_in_source
    assert_nil user.marketing_opt_out_reason
    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_resubscribed")
    assert event.processed_at.present?
  end

  test "a hard bounce followed by an unsubscribed event settles on hard_bounce with the earlier opt-out time" do
    user = users(:marketing_subscribed)
    earlier_time = 5.minutes.from_now.to_i
    later_time = 10.minutes.from_now.to_i

    bounce_body = {
      "eventName" => "email.hardBounced",
      "eventTime" => earlier_time,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json
    unsubscribed_body = {
      "eventName" => "contact.unsubscribed",
      "eventTime" => later_time,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    LoopsWebhookSignature.stub(:secret, LOOPS_WEBHOOK_TEST_SECRET) do
      assert_no_enqueued_jobs only: LoopsContactSyncJob do
        post_loops_webhook(webhook_id: "wh_order_a_bounce", body: bounce_body)
        assert_response :ok
        post_loops_webhook(webhook_id: "wh_order_a_unsubscribed", body: unsubscribed_body)
        assert_response :ok
        perform_enqueued_jobs only: LoopsWebhookEventJob
      end
    end

    user.reload
    assert_equal "hard_bounce", user.marketing_opt_out_reason
    assert_in_delta earlier_time, user.marketing_opt_out_at.to_i, 1
  end

  test "an unsubscribed event followed by a hard bounce escalates to hard_bounce with the earlier opt-out time" do
    user = users(:marketing_subscribed)
    earlier_time = 5.minutes.from_now.to_i
    later_time = 10.minutes.from_now.to_i

    unsubscribed_body = {
      "eventName" => "contact.unsubscribed",
      "eventTime" => earlier_time,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json
    bounce_body = {
      "eventName" => "email.hardBounced",
      "eventTime" => later_time,
      "contactIdentity" => {"userId" => user.id.to_s}
    }.to_json

    LoopsWebhookSignature.stub(:secret, LOOPS_WEBHOOK_TEST_SECRET) do
      assert_no_enqueued_jobs only: LoopsContactSyncJob do
        post_loops_webhook(webhook_id: "wh_order_b_unsubscribed", body: unsubscribed_body)
        assert_response :ok
        post_loops_webhook(webhook_id: "wh_order_b_bounce", body: bounce_body)
        assert_response :ok
        perform_enqueued_jobs only: LoopsWebhookEventJob
      end
    end

    user.reload
    assert_equal "hard_bounce", user.marketing_opt_out_reason
    assert_in_delta earlier_time, user.marketing_opt_out_at.to_i, 1
  end

  test "an event for an unknown user is recorded and marked processed without raising" do
    body = {
      "eventName" => "contact.unsubscribed",
      "eventTime" => Time.current.to_i,
      "contactIdentity" => {"userId" => "999999999", "email" => "no-such-user-#{SecureRandom.hex(4)}@example.com"}
    }.to_json

    LoopsWebhookSignature.stub(:secret, LOOPS_WEBHOOK_TEST_SECRET) do
      assert_difference "LoopsWebhookEvent.count", 1 do
        post_loops_webhook(webhook_id: "wh_unknown_user", body: body)
      end
      assert_response :ok

      assert_nothing_raised do
        perform_enqueued_jobs only: LoopsWebhookEventJob
      end
    end

    event = LoopsWebhookEvent.find_by!(webhook_id: "wh_unknown_user")
    assert event.processed_at.present?
  end
end
