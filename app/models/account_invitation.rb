class AccountInvitation < ApplicationRecord
  ROLES = AccountUser::ROLES

  include AccountUser::Roles

  belongs_to :account
  belongs_to :invited_by, class_name: "User", optional: true
  has_secure_token

  validates :name, :email, presence: true
  validates :email, uniqueness: {scope: :account_id, message: :invited}

  def save_and_send_invite = save && send_invite
  def send_invite = AccountMailer.with(account_invitation: self).invite.deliver_later

  def accept!(user)
    result = FamilyInvitationAcceptance.new(invitation: self, user: user).call
    unless result.success?
      errors.add(:base, result.error)
      return
    end

    [account.owner, invited_by].uniq.each { |recipient| Account::AcceptedInviteNotifier.with(account: account, record: user).deliver(recipient) }
    result.account_user
  end

  def reject! = destroy
  def to_param = token
end
