class User < ApplicationRecord
  include AccountCreatedEmail, Accounts, Agreements, Authenticatable, MarketingConsent, Mentions, Notifiable, Profile, Searchable, Theme
end
