class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types

  FREE_STUDENT_LIMIT = 2
  MAX_PARENTS = 2
  # Pay statuses of a subscription that has ended; everything else can still bill and so needs cancelling on delete.
  ENDED_SUBSCRIPTION_STATUSES = %w[canceled incomplete_expired].freeze

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :personal, exclusion: {in: [true], message: "must be false"}
  validates :student_limit, numericality: {only_integer: true, greater_than_or_equal_to: FREE_STUDENT_LIMIT}
  validates :complimentary_premium_note, presence: true, if: :complimentary_premium?

  # AIDEV-NOTE: The database default is the single source for the Premium cap
  # advertised to signed-out visitors and Free families.
  def self.default_student_limit
    column_defaults.fetch("student_limit").to_i
  end

  before_destroy :cancel_live_subscriptions!
  after_update_commit :sync_plan_status_to_marketing_subscribed_parents, if: :saved_change_to_complimentary_premium?

  def parents
    admins
  end

  def full?
    account_users_count >= MAX_PARENTS
  end

  # Pending invitations hold a seat, so a family can't invite past its parent limit.
  def invitations_full?
    account_users_count + account_invitations.count >= MAX_PARENTS
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  # AIDEV-NOTE: Complimentary Premium is an account switch rather than a fake
  # Pay subscription, keeping testers out of billing records and revenue numbers.
  # It has no end date and stays on until a superadmin switches it off.
  def premium?
    complimentary_premium? || paid_premium?
  end

  # AIDEV-NOTE: Paid Premium wins over complimentary access so converted testers
  # report premium; Loops sync (COV-76) and pricing/billing pages (COV-77) use this.
  def plan_status
    return "premium" if paid_premium?
    return "complimentary" if complimentary_premium?

    "free"
  end

  def paid_premium?
    billable_subscriptions.exists?
  end

  def free?
    !premium?
  end

  # AIDEV-NOTE: Premium is advertised as unlimited, but student_limit (default
  # 10, raised per family by a superadmin) is the real cap that keeps co-ops
  # and micro-schools off a family plan; families above it contact support. No
  # per-student fee — pricing stays flat per family and Stripe quantity never changes.
  def students_allowed
    premium? ? student_limit : FREE_STUDENT_LIMIT
  end

  def joinable_by?(user)
    unjoinable_reason(user).nil?
  end

  # Distinguishes *why* a family can't be merged so callers can give an
  # actionable message instead of a generic block (AccountInvitation
  # acceptance shows a different message per reason).
  def unjoinable_reason(user)
    return :other_members unless account_users.one? && users.exists?(user.id)
    return :other_members unless students_empty?
    return :billable_subscription if renewing_subscriptions.any?
    nil
  end

  def sync_plan_status_to_marketing_subscribed_parents
    parents.marketing_subscribed.find_each do |parent|
      LoopsContactSyncJob.perform_later(parent.id, "plan_status")
    end
  end

  private

  def students_empty?
    !respond_to?(:students) || students.none?
  end

  # AIDEV-NOTE: Three deliberately different subscription sets. Billable = paying now (Pay's `active` scope also
  # covers trials and paid-through cancellations) and drives Premium. Live = anything not ended, which deletion must
  # cancel. Renewing = billable and not set to cancel, which is what blocks joining another family. Plan changes
  # (PlanChangeGuard) ask a different question about one subscription, so they don't share these.
  def billable_subscriptions
    pay_subscriptions.active.or(pay_subscriptions.past_due)
  end

  def live_subscriptions
    pay_subscriptions.where.not(status: ENDED_SUBSCRIPTION_STATUSES)
  end

  # AIDEV-NOTE: A canceled-but-still-paid subscription stays with the archived
  # family and runs out, so it does not prevent that parent from joining another family.
  def renewing_subscriptions
    billable_subscriptions.where(ends_at: nil)
  end

  def cancel_live_subscriptions!
    live_subscriptions.find_each do |subscription|
      # AIDEV-NOTE: Release a pending plan switch before cancelling. If the release fails, log it and still
      # cancel: ending the paid subscription matters more than clearing the schedule.
      begin
        subscription.release_schedule!
      rescue Pay::Error => error
        Rails.logger.error("[Account] Could not release schedule for #{subscription.processor_id}: #{error.message}")
      end
      subscription.cancel_now!
    end
  end
end
