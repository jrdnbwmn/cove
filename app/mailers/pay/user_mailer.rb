module Pay
  class UserMailer < Pay.parent_mailer.constantize
    def receipt
      pay_charge = params.fetch(:pay_charge)
      receipt = pay_charge.receipt
      raise "Receipt PDF is missing" if receipt.blank?

      attachments[pay_charge.receipt_filename] = {
        mime_type: "application/pdf",
        content: receipt
      }

      loops_mail(
        :receipt,
        {
          amount: Pay::Currency.format(pay_charge.amount, currency: pay_charge.currency),
          charged_to: pay_charge.charged_to,
          transaction_id: pay_charge.processor_id,
          charged_at: I18n.l(pay_charge.created_at, format: :long)
        },
        pay_charge.processor_id,
        include_billing_info: true
      )
    end

    def refund
      pay_charge = params.fetch(:pay_charge)

      loops_mail(
        :refund,
        {
          amount_refunded: Pay::Currency.format(pay_charge.amount_refunded, currency: pay_charge.currency),
          charged_to: pay_charge.charged_to,
          transaction_id: pay_charge.processor_id,
          charged_at: I18n.l(pay_charge.created_at, format: :long)
        },
        "#{pay_charge.processor_id}:#{pay_charge.amount_refunded}",
        include_billing_info: true
      )
    end

    def subscription_renewing
      subscription = params.fetch(:pay_subscription)
      renewal_date = params.fetch(:date)

      loops_mail(
        :subscription_renewing,
        {renews_on: I18n.l(renewal_date.to_date, format: :long), manage_subscription_url: billing_url},
        "#{subscription.processor_id}:#{renewal_date.iso8601}"
      )
    end

    def payment_action_required
      payment_intent_id = params.fetch(:payment_intent_id)

      loops_mail(
        :payment_action_required,
        {confirm_payment_url: pay.payment_url(payment_intent_id)},
        payment_intent_id
      )
    end

    def payment_failed
      invoice = params.fetch(:stripe_invoice)

      loops_mail(
        :payment_failed,
        {update_billing_url: billing_url},
        "#{invoice.id}:#{invoice.attempt_count}"
      )
    end

    def subscription_trial_will_end
      trial_mail(:subscription_trial_will_end)
    end

    def subscription_trial_ended
      trial_mail(:subscription_trial_ended)
    end

    private

    def loops_mail(action, data_variables, seed, include_billing_info: false)
      if include_billing_info
        billing_info = params.fetch(:pay_customer).owner.extra_billing_info.to_s.first(500)
        data_variables[:extra_billing_info] = billing_info if billing_info.present?
      end

      mail mail_arguments.merge(
        "X-Loops-Transactional-Id": Rails.application.config_for(:loops).transactional.fetch(action),
        "X-Loops-Data-Variables": data_variables.to_json,
        "X-Loops-Idempotency-Seed": seed,
        body: ""
      )
    end

    def mail_arguments
      instance_exec(&Pay.mail_arguments)
    end

    def trial_mail(action)
      subscription = params.fetch(:pay_subscription)
      trial_end = subscription.trial_ends_at

      loops_mail(action, {manage_subscription_url: billing_url}, "#{subscription.processor_id}:#{trial_end.iso8601}")
    end
  end
end
