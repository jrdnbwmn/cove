class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types

  FREE_LEARNER_LIMIT = 2
  MAX_PARENTS = 2
  # Pay statuses of a subscription that has ended; everything else can still bill and so needs cancelling on delete.
  ENDED_SUBSCRIPTION_STATUSES = %w[canceled incomplete_expired].freeze

  has_many :learners, dependent: :destroy

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :personal, exclusion: {in: [true], message: "must be false"}
  validates :learner_limit, numericality: {only_integer: true, greater_than_or_equal_to: FREE_LEARNER_LIMIT}
  validates :complimentary_premium_note, presence: true, if: :complimentary_premium?

  # AIDEV-NOTE: The database default is the single source for the Premium cap
  # advertised to signed-out visitors and Free families.
  def self.default_learner_limit
    column_defaults.fetch("learner_limit").to_i
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
    # AIDEV-NOTE: This is memoized per model instance only; callers that change
    # subscriptions mid-request must reload before asking again.
    return @paid_premium if defined?(@paid_premium)

    @paid_premium = billable_subscriptions.exists?
  end

  def reload(*)
    remove_instance_variable(:@paid_premium) if defined?(@paid_premium)
    remove_instance_variable(:@over_free_learner_limit) if defined?(@over_free_learner_limit)
    super
  end

  def free?
    !premium?
  end

  # AIDEV-NOTE: Premium is advertised as unlimited, but learner_limit (default
  # 10, raised per family by a superadmin) is the real cap that keeps co-ops
  # and micro-schools off a family plan; families above it contact support. No
  # per-learner fee — pricing stays flat per family and Stripe quantity never changes.
  def learners_allowed
    premium? ? learner_limit : FREE_LEARNER_LIMIT
  end

  # Fresh count query (not learners.size) so a loaded association can't answer stale.
  def can_add_learner?
    learners.active.count < learners_allowed
  end

  # AIDEV-NOTE: The result is memoized for one rendered page because every
  # learner card asks it. Reload clears it when a request changes the family.
  def over_free_learner_limit?
    return @over_free_learner_limit if defined?(@over_free_learner_limit)

    @over_free_learner_limit = free? && learners.active.count > FREE_LEARNER_LIMIT
  end

  def learner_pick_needed?
    over_free_learner_limit? && learners.active.where(kept_on_free: true).count < FREE_LEARNER_LIMIT
  end

  def keep_learners_on_free(ids)
    errors.clear
    ids = Array(ids)

    with_lock do
      valid_ids = ids.size == FREE_LEARNER_LIMIT && ids.uniq.size == FREE_LEARNER_LIMIT &&
        learners.active.where(id: ids).count == FREE_LEARNER_LIMIT
      return invalid_learner_pick unless valid_ids

      learners.update_all(kept_on_free: false)
      learners.active.where(id: ids).update_all(kept_on_free: true)
    end

    true
  end

  def joinable_by?(user)
    unjoinable_reason(user).nil?
  end

  # Distinguishes *why* a family can't be merged so callers can give an
  # actionable message instead of a generic block (AccountInvitation
  # acceptance shows a different message per reason).
  def unjoinable_reason(user)
    return :other_members unless account_users.one? && users.exists?(user.id)
    return :has_learners unless learners_empty?
    return :billable_subscription if renewing_subscriptions.any?
    nil
  end

  def sync_plan_status_to_marketing_subscribed_parents
    parents.marketing_subscribed.find_each do |parent|
      LoopsContactSyncJob.perform_later(parent.id, "plan_status")
    end
  end

  private

  def learners_empty?
    learners.none?
  end

  def invalid_learner_pick
    errors.add(:base, I18n.t("learners.kept.error", limit: FREE_LEARNER_LIMIT))
    false
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
