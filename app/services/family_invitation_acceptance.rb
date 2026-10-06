class FamilyInvitationAcceptance
  Result = Data.define(:account_user, :error) do
    def success? = account_user.present?
  end

  def initialize(invitation:, user:)
    @invitation = invitation
    @user = user
  end

  def call
    return Result.new(nil, I18n.t("family_invitation_acceptance.wrong_recipient")) unless invitation.email.casecmp?(user.email)

    ApplicationRecord.transaction do
      invitation.lock!
      user.lock!
      target = invitation.account
      source = user.family
      [target, source].compact.uniq.sort_by(&:id).each(&:lock!)

      return Result.new(nil, I18n.t("family_invitation_acceptance.archived")) if target.archived?
      return Result.new(nil, I18n.t("family_invitation_acceptance.full")) if target.full?

      return Result.new(nil, I18n.t("family_invitation_acceptance.already_member")) if source == target

      if source
        case source.unjoinable_reason(user)
        when :other_members
          return Result.new(nil, I18n.t("family_invitation_acceptance.other_members"))
        when :has_learners
          return Result.new(nil, I18n.t("family_invitation_acceptance.has_learners"))
        when :billable_subscription
          return Result.new(nil, I18n.t("family_invitation_acceptance.billable_subscription"))
        end

        source.account_users.find_by!(user: user).destroy!
        source.account_invitations.destroy_all
        source.archive!
      end

      account_user = target.account_users.create!(user: user, admin: true)
      invitation.destroy!
      # AIDEV-NOTE: user.family was memoized from `source` above; reload so callers see the new family.
      user.reload
      Result.new(account_user, nil)
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(nil, I18n.t("family_invitation_acceptance.already_belongs"))
  rescue ActiveRecord::Deadlocked
    Result.new(nil, I18n.t("family_invitation_acceptance.try_again"))
  end

  private

  attr_reader :invitation, :user
end
