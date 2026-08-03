class User < ApplicationRecord
  include Accounts, Agreements, Authenticatable, MarketingConsent, Mentions, Notifiable, Profile, Searchable, Theme
end
