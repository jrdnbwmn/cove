module User::MarketingConsent
  extend ActiveSupport::Concern

  CONSENT_ATTRIBUTES = %w[
    marketing_opt_in_at
    marketing_opt_in_source
    marketing_opt_out_at
    marketing_opt_out_reason
  ].freeze
  MARKETING_OPT_IN_SOURCES = %w[registration settings loops].freeze
  MARKETING_OPT_OUT_REASONS = %w[
    user_app
    user_loops
    mailing_list_unsubscribe
    hard_bounce
    spam_report
  ].freeze
  PROTECTED_MARKETING_OPT_OUT_REASONS = (MARKETING_OPT_OUT_REASONS - ["user_app"]).freeze

  included do
    attribute :marketing_opt_in, :boolean

    validates :marketing_opt_in_source, inclusion: {in: MARKETING_OPT_IN_SOURCES}, allow_nil: true
    validates :marketing_opt_out_reason, inclusion: {in: MARKETING_OPT_OUT_REASONS}, allow_nil: true

    before_validation :capture_registration_marketing_consent, on: :create
    before_validation :clear_hard_bounce_after_email_change

    after_create_commit :enqueue_contact_opt_in, if: :current_app_marketing_opt_in?
    after_update_commit :enqueue_contact_sync
    after_destroy_commit :enqueue_contact_deletion
  end

  class_methods do
    def marketing_subscribed
      where.not(marketing_opt_in_at: nil).where(marketing_opt_out_at: nil)
    end
  end

  def marketing_subscribed?
    marketing_opt_in_at.present? && marketing_opt_out_at.nil?
  end

  def marketing_opt_out_protected?
    marketing_opt_out_reason.in?(PROTECTED_MARKETING_OPT_OUT_REASONS)
  end

  def grant_marketing_consent(source:)
    return self if marketing_subscribed?

    if marketing_opt_out_protected?
      errors.add(:base, :marketing_opt_out_protected)
      return false
    end

    self.marketing_opt_in_at = Time.current
    self.marketing_opt_in_source = source
    self.marketing_opt_out_at = nil
    self.marketing_opt_out_reason = nil

    save ? self : false
  end

  def withdraw_marketing_consent(reason:)
    return self unless marketing_subscribed?

    self.marketing_opt_out_at = Time.current
    self.marketing_opt_out_reason = reason

    save ? self : false
  end

  private

  def capture_registration_marketing_consent
    return unless marketing_opt_in? && !marketing_subscribed?

    self.marketing_opt_in_at = Time.current
    self.marketing_opt_in_source = "registration"
  end

  def clear_hard_bounce_after_email_change
    clear_marketing_consent if persisted? && will_save_change_to_email? && marketing_opt_out_reason == "hard_bounce"
  end

  def clear_marketing_consent
    self.marketing_opt_in_at = nil
    self.marketing_opt_in_source = nil
    self.marketing_opt_out_at = nil
    self.marketing_opt_out_reason = nil
  end

  def enqueue_contact_opt_in
    LoopsContactSyncJob.perform_later(id, "opt_in")
  end

  def current_app_marketing_opt_in?
    marketing_subscribed? && marketing_opt_in_source != "loops"
  end

  def enqueue_contact_sync
    if saved_change_to_marketing_opt_in_at? && marketing_subscribed? && marketing_opt_in_source != "loops"
      LoopsContactSyncJob.perform_later(id, "opt_in")
    elsif saved_change_to_marketing_opt_out_at? && marketing_opt_out_reason == "user_app"
      LoopsContactSyncJob.perform_later(id, "opt_out")
    elsif saved_change_to_email? && marketing_opt_in_at_before_last_save.present?
      LoopsContactSyncJob.perform_later(id, "email_change")
    end
  end

  def enqueue_contact_deletion
    LoopsContactDeletionJob.perform_later(id.to_s)
  end
end
