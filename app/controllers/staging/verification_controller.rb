class Staging::VerificationController < ApplicationController
  before_action :authenticate_user!
  before_action :operator!

  # AIDEV-NOTE: This controller is a temporary staging-only COV-47 verification
  # bridge. Remove its route, controller, and tests after the verification run.
  def status
    render json: {
      loops_delivery_enabled: Rails.application.config.action_mailer.delivery_method == :loops,
      perform_deliveries: Rails.application.config.action_mailer.perform_deliveries,
      operator_allowlisted: allowlisted?(current_user.email),
      billing_email_allowlisted: allowlisted?(current_account.billing_email),
      audit: audit_summary
    }
  end

  def audit
    render json: {audit: audit_summary}
  end

  def create_plan
    price_id = params[:price_id].to_s
    return render_unprocessable("A Stripe price identifier is required") unless price_id.start_with?("price_")

    plan = Plan.find_or_initialize_by(name: verification_plan_name)
    if plan.new_record?
      plan.assign_attributes(amount: 9900, currency: "usd", interval: "year", trial_period_days: 0, hidden: false)
    end
    plan.stripe_id = price_id
    plan.save!

    render json: {created: plan.previously_new_record?, plan_id: plan.id}
  end

  def invite
    invitation = AccountInvitation.new(
      account: current_account,
      email: current_user.email,
      name: "COV-47 Invite Check",
      invited_by: current_user
    )
    return render_unprocessable(invitation.errors.full_messages.to_sentence) unless invitation.save_and_send_invite

    render json: {invited: true}
  end

  def subscription_renewing
    with_subscription do |customer, subscription|
      Pay::UserMailer.with(pay_customer: customer, pay_subscription: subscription, date: 1.year.from_now)
        .subscription_renewing.deliver_now
    end
  end

  def subscription_trial_will_end
    deliver_trial_mail(:subscription_trial_will_end, 3.days.from_now)
  end

  def subscription_trial_ended
    deliver_trial_mail(:subscription_trial_ended, 1.day.ago)
  end

  def cancellation_reason
    with_subscription do |_customer, subscription|
      AccountMailer.with(subscription:, user: current_user).cancellation_reason.deliver_now
    end
  end

  def enqueue_failure
    FailureMailer.with(user: current_user).deliberately_invalid.deliver_later
    render json: {enqueued: true}
  end

  def cleanup
    plan_count = Plan.where(name: verification_plan_name).destroy_all.count
    invitation_count = AccountInvitation.where(account: current_account, email: current_user.email).destroy_all.count

    render json: {plans_removed: plan_count, invitations_removed: invitation_count}
  end

  # AIDEV-NOTE: Staging-only escape hatch for a stray, non-COV-47 subscription (e.g. the
  # seeded fake_processor "Cove Dev Plan") blocking checkout via Pay::Customer#subscribed?.
  # Force-ends it immediately rather than the UI's cancel-at-period-end.
  def clear_stray_subscription
    canceled = current_account.pay_subscriptions.active.reject { |subscription| subscription.plan&.name == verification_plan_name }
    canceled.each(&:cancel_now!)

    render json: {canceled_count: canceled.size}
  end

  # AIDEV-NOTE: The UI cancels annual subscriptions at period end, which prevents the
  # COV-47 failure-path checkout checks. This temporary staging-only action ends only
  # the named verification subscription after its cancellation-survey job has run.
  def cancel_verification_subscription
    canceled = current_account.pay_subscriptions.active.select { |subscription| subscription.plan&.name == verification_plan_name }
    canceled.each(&:cancel_now!)

    render json: {canceled_count: canceled.size}
  end

  def link_test_clock_customer
    customer_id = params[:customer_id].to_s
    return render_unprocessable("A Stripe customer identifier is required") unless customer_id.start_with?("cus_")

    current_account.pay_customers.where(processor: :stripe).destroy_all
    customer = Pay::Customer.create!(owner: current_account, processor: :stripe, processor_id: customer_id, default: true)
    render json: {customer_linked: customer.persisted?}
  end

  # AIDEV-NOTE: Staging-only escape hatch for a local Pay::Customer whose processor_id
  # points at a Stripe customer from a since-corrected/mismatched Stripe account. Destroys
  # it so the next checkout creates a fresh customer against the current credentials.
  def reset_stripe_customer
    removed = current_account.pay_customers.where(processor: :stripe).destroy_all

    render json: {removed_count: removed.size}
  end

  private

  def operator!
    configured_email = ENV["STAGING_VERIFICATION_OPERATOR_EMAIL"].to_s
    return if configured_email.present? && ActiveSupport::SecurityUtils.secure_compare(current_user.email, configured_email)

    head :not_found
  end

  def current_account
    @current_account ||= current_user.accounts.first
  end

  def with_subscription
    customer = current_account&.payment_processor
    subscription = customer&.subscriptions&.last
    return render_unprocessable("A subscription is required") unless customer && subscription

    yield customer, subscription
    render json: {sent: true}
  end

  def deliver_trial_mail(action, trial_end)
    with_subscription do |customer, subscription|
      original_trial_end = subscription.trial_ends_at
      subscription.update_columns(trial_ends_at: trial_end)
      Pay::UserMailer.with(pay_customer: customer, pay_subscription: subscription).public_send(action).deliver_now
    ensure
      subscription&.update_columns(trial_ends_at: original_trial_end)
    end
  end

  def render_unprocessable(message)
    render json: {error: message}, status: :unprocessable_content
  end

  def verification_plan_name = "COV-47 Verification (Yearly)"

  def allowlisted?(email)
    allowlist.include?(email.to_s.downcase)
  end

  def allowlist
    ENV.fetch("STAGING_EMAIL_RECIPIENT_ALLOWLIST", "").split(",").map { |email| email.strip.downcase }.reject(&:blank?)
  end

  def audit_summary
    emails = User.pluck(:email) + Account.where.not(billing_email: [nil, ""]).pluck(:billing_email)
    {
      recipient_count: emails.count,
      non_allowlisted_count: emails.count { |email| !allowlisted?(email) },
      masked_recipients: emails.uniq.map { |email| mask(email) }
    }
  end

  def mask(email)
    local, domain = email.to_s.split("@", 2)
    return "[invalid]" if local.blank? || domain.blank?

    "#{local.first}***@#{domain}"
  end

  class FailureMailer < ApplicationMailer
    def deliberately_invalid
      mail(
        to: params.fetch(:user).email,
        "X-Loops-Transactional-Id": "cov47_deliberately_invalid_id",
        "X-Loops-Data-Variables": "{}",
        body: ""
      )
    end
  end
end
