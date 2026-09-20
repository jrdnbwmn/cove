class AccountUser < ApplicationRecord
  ROLES = [:admin]

  include Ownership, Roles

  # AIDEV-NOTE: Families use flat billing. Keep this override without
  # UpdatesSubscriptionQuantity when merging Jumpstart updates.
  validates :admin, inclusion: {in: [true], message: "must be an admin"}
  validate :user_has_no_other_family
  validate :family_has_capacity, on: :create
  after_commit :enqueue_plan_status_sync, on: [:create, :destroy]

  private

  def user_has_no_other_family
    return if user_id.blank? || self.class.where(user_id: user_id).where.not(id: id).none?

    errors.add(:user, "already belongs to a family")
  end

  def family_has_capacity
    return unless account&.full?

    errors.add(:base, "Family already has two parents")
  end

  def enqueue_plan_status_sync
    user = User.find_by(id: user_id)
    return unless user&.marketing_subscribed?

    LoopsContactSyncJob.perform_later(user.id, "plan_status")
  end
end
