require "test_helper"
require "ostruct"

class Pay::UserMailerTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:company)
    @account.update!(extra_billing_info: "VAT-123")
    @customer = @account.set_payment_processor(:fake_processor, allow_fake: true)
    @charge = @customer.charge(10_00)
  end

  test "receipt builds a bodyless Loops message with variables, seed, and PDF attachment" do
    @charge.stub(:receipt, "%PDF-1.4\nfull receipt") do
      @charge.stub(:receipt_filename, "receipt.pdf") do
        message = Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).receipt.message

        assert message.multipart?
        assert_equal "", message.text_part.body.to_s
        assert_equal "cmsdrk6tf03rb0jzw194l0rl5", message["X-Loops-Transactional-Id"].value
        assert_equal @charge.processor_id.to_s, message["X-Loops-Idempotency-Seed"].value
        assert_equal(
          {
            "amount" => Pay::Currency.format(@charge.amount, currency: @charge.currency),
            "charged_to" => @charge.charged_to,
            "transaction_id" => @charge.processor_id,
            "charged_at" => I18n.l(@charge.created_at, format: :long),
            "extra_billing_info" => "VAT-123"
          },
          JSON.parse(message["X-Loops-Data-Variables"].value)
        )
        assert_equal ["receipt.pdf"], message.attachments.map(&:filename)
        assert_equal "%PDF-1.4\nfull receipt", message.attachments.first.decoded
        assert_equal "application/pdf", message.attachments.first.mime_type
      end
    end
  end

  test "refund builds a bodyless Loops message with capped billing information and a distinct seed" do
    @account.update!(extra_billing_info: "x" * 501)
    @charge.update!(amount_refunded: 5_00)

    message = Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).refund.message

    assert_not message.multipart?
    assert_equal "", message.body.to_s
    assert_equal "cmsdrk8f603rc0jzn1pmslh4m", message["X-Loops-Transactional-Id"].value
    assert_equal "#{@charge.processor_id}:500", message["X-Loops-Idempotency-Seed"].value
    assert_equal(
      {
        "amount_refunded" => Pay::Currency.format(@charge.amount_refunded, currency: @charge.currency),
        "charged_to" => @charge.charged_to,
        "transaction_id" => @charge.processor_id,
        "charged_at" => I18n.l(@charge.created_at, format: :long),
        "extra_billing_info" => "x" * 500
      },
      JSON.parse(message["X-Loops-Data-Variables"].value)
    )
  end

  test "receipt generation failures prevent a message from being built" do
    @charge.stub(:receipt, -> { raise "PDF failed" }) do
      assert_raises(RuntimeError, "PDF failed") do
        Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).receipt.message
      end
    end
  end

  test "missing receipt generation prevents a message from being built" do
    @charge.stub(:receipt, "") do
      assert_raises(RuntimeError, "Receipt PDF is missing") do
        Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).receipt.message
      end
    end
  end

  test "Pay mailer shadow exposes all seven billing actions" do
    expected_actions = %i[
      receipt refund subscription_renewing payment_action_required payment_failed
      subscription_trial_will_end subscription_trial_ended
    ]

    assert_equal expected_actions.sort, Pay::UserMailer.public_instance_methods(false).intersection(expected_actions).sort
  end

  test "remaining billing actions use their published IDs, variables, URLs, and stable seeds" do
    subscription = OpenStruct.new(processor_id: "sub_123", trial_ends_at: Time.zone.parse("2026-09-01 12:00:00"))
    renewal_date = Time.zone.parse("2026-08-20 12:00:00")
    invoice = OpenStruct.new(id: "in_123", attempt_count: 2)
    billing_url = Rails.application.routes.url_helpers.billing_url(**Rails.application.config.action_mailer.default_url_options)

    cases = {
      subscription_renewing: [{pay_customer: @customer, pay_subscription: subscription, date: renewal_date}, "cmsdru6vf04dv0j15pwbonmxs", {"renews_on" => I18n.l(renewal_date.to_date, format: :long), "manage_subscription_url" => billing_url}, "sub_123:#{renewal_date.iso8601}"],
      payment_action_required: [{pay_customer: @customer, payment_intent_id: "pi_123"}, "cmsdrxthi04p90jzc3bwkq7kj", {"confirm_payment_url" => Pay::Engine.routes.url_helpers.payment_url("pi_123", **Rails.application.config.action_mailer.default_url_options)}, "pi_123"],
      payment_failed: [{pay_customer: @customer, stripe_invoice: invoice}, "cmsdrxtnb04qk0j3oclaszs7k", {"update_billing_url" => billing_url}, "in_123:2"],
      subscription_trial_will_end: [{pay_customer: @customer, pay_subscription: subscription}, "cmsdru71a04c50jzw6rqtt95u", {"manage_subscription_url" => billing_url}, "sub_123:#{subscription.trial_ends_at.iso8601}"],
      subscription_trial_ended: [{pay_customer: @customer, pay_subscription: subscription}, "cmsdru76v04ep0jw7xrbb236w", {"manage_subscription_url" => billing_url}, "sub_123:#{subscription.trial_ends_at.iso8601}"]
    }

    cases.each do |action, (params, transactional_id, variables, seed)|
      message = Pay::UserMailer.with(**params).public_send(action).message

      assert_not message.multipart?, action
      assert_equal "", message.body.to_s, action
      assert_equal transactional_id, message["X-Loops-Transactional-Id"].value, action
      assert_equal seed, message["X-Loops-Idempotency-Seed"].value, action
      assert_equal variables, JSON.parse(message["X-Loops-Data-Variables"].value), action
    end
  end

  test "distinct billing events produce distinct seeds while replays remain stable" do
    @charge.update!(amount_refunded: 1_00)
    first_refund = Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).refund.message["X-Loops-Idempotency-Seed"].value
    replay_refund = Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).refund.message["X-Loops-Idempotency-Seed"].value
    @charge.update!(amount_refunded: 2_00)
    later_refund = Pay::UserMailer.with(pay_customer: @customer, pay_charge: @charge).refund.message["X-Loops-Idempotency-Seed"].value

    assert_equal first_refund, replay_refund
    assert_not_equal first_refund, later_refund
  end
end
