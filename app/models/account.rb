class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :personal, exclusion: {in: [true], message: "must be false"}

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
