module AccountUser::Ownership
  extend ActiveSupport::Concern

  included do
    belongs_to :account, counter_cache: true
    belongs_to :user

    validates :user_id, uniqueness: {scope: :account_id}
    validate :owner_must_be_admin, on: :update, if: -> { admin_changed? && account_owner? }
  end

  def account_owner?
    account.owner?(user)
  end

  def owner_must_be_admin
    errors.add :admin, :cannot_be_removed unless admin?
  end
end
