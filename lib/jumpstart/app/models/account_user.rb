class AccountUser < ApplicationRecord
  # Do NOT to use any reserved words like `user` or `account`
  ROLES = [:admin]

  include Ownership, Roles, UpdatesSubscriptionQuantity
end
