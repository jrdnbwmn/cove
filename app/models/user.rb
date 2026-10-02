class User < ApplicationRecord
  include AccountCreatedEmail, Accounts, Agreements, Authenticatable, MarketingConsent, Mentions, Notifiable, Profile, Searchable, Theme

  attr_accessor :invitation_signup

  # AIDEV-NOTE: A password change revokes every API token on purpose, including the
  # token used by Api::V1::PasswordsController. No native app ships yet, so nothing
  # needs a re-issued token.
  after_update :revoke_api_tokens, if: :saved_change_to_encrypted_password?

  scope :by_email, ->(email) { where(email: email.to_s.strip.downcase) }

  def family
    # AIDEV-NOTE: This is memoized per model instance only; callers that change
    # membership mid-request must reload before asking again.
    @family ||= accounts.active.first
  end

  def reload(*)
    remove_instance_variable(:@family) if defined?(@family)
    super
  end

  def must_transfer_family_before_deletion?
    family&.owner?(self) && family.parents.where.not(id: id).exists?
  end

  def create_default_account
    return family if family
    return if invitation_signup

    owned_accounts.create!(name: "#{name}'s Family", personal: false)
  end

  private

  def revoke_api_tokens
    api_tokens.destroy_all
  end
end
