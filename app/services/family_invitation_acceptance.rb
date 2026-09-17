class FamilyInvitationAcceptance
  Result = Data.define(:account_user, :error) do
    def success? = account_user.present?
  end

  def initialize(invitation:, user:)
    @invitation = invitation
    @user = user
  end

  def call
    return Result.new(nil, "This invitation was sent to someone else") unless invitation.email.casecmp?(user.email)

    ApplicationRecord.transaction do
      invitation.lock!
      target = invitation.account.lock!
      return Result.new(nil, "Family already has two parents") if target.full?

      user.lock!
      source = user.family
      source&.lock!
      return Result.new(nil, "You are already in this family") if source == target

      if source
        case source.unjoinable_reason(user)
        when :other_members
          return Result.new(nil, "Your family has another parent. Contact support to join a new family.")
        when :billable_subscription
          return Result.new(nil, "Cancel your Premium subscription first, then accept this invitation.")
        end

        source.account_users.find_by!(user: user).destroy!
        source.archive!
      end

      account_user = target.account_users.create!(user: user, admin: true)
      invitation.destroy!
      Result.new(account_user, nil)
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(nil, "You already belong to a family")
  end

  private

  attr_reader :invitation, :user
end
