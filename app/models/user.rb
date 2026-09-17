class User < ApplicationRecord
  include AccountCreatedEmail, Accounts, Agreements, Authenticatable, MarketingConsent, Mentions, Notifiable, Profile, Searchable, Theme

  attr_accessor :invitation_signup

  scope :by_email, ->(email) { where("LOWER(email) = ?", email.to_s.downcase) }

  def family
    accounts.active.first
  end

  def must_transfer_family_before_deletion?
    family&.owner?(self) && family.parents.where.not(id: id).exists?
  end

  def create_default_account
    return family if family
    return if invitation_signup

    owned_accounts.create!(name: "#{name}'s Family", personal: false)
  end
end
