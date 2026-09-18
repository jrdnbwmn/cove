class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types

  FREE_STUDENT_LIMIT = 1

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :personal, exclusion: {in: [true], message: "must be false"}
  validates :student_limit, numericality: {only_integer: true, greater_than_or_equal_to: 1}

  before_destroy :cancel_billable_subscriptions!

  def parents
    admins
  end

  def full?
    account_users_count >= 2
  end

  def archive!
    update!(archived_at: Time.current)
  end

  # AIDEV-NOTE: Premium follows billable subscriptions, never a price, plan, or
  # Stripe ID, so old-price families remain Premium. It includes past_due while
  # Stripe retries; COV-75 will add complimentary Premium.
  def premium?
    billable_subscriptions.exists?
  end

  def free?
    !premium?
  end

  # AIDEV-NOTE: The Premium cap prevents co-ops and micro-schools from using a
  # family plan. A per-student fee or add-on may replace manual admin raises.
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
    return :billable_subscription if billable_subscriptions.any?
    nil
  end

  private

  def students_empty?
    !respond_to?(:students) || students.none?
  end

  def billable_subscriptions
    pay_subscriptions.active.or(pay_subscriptions.past_due)
  end

  def cancel_billable_subscriptions!
    billable_subscriptions.find_each(&:cancel_now!)
  end
end
