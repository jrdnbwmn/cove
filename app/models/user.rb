class User < ApplicationRecord
  include Accounts, Agreements, Authenticatable, Mentions, Notifiable, Profile, Searchable, Theme
end
