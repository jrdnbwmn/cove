# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

unless Rails.env.production?
  # AIDEV-NOTE: Relies on User#create_default_account (lib/jumpstart/app/models/user/accounts.rb)
  # auto-creating a personal account on create. That hook only fires when
  # Jumpstart.config.personal_accounts? is true (default account_types "both"). If account_types
  # is ever changed to exclude personal accounts, these seeds must create personal accounts explicitly.

  owner = User.find_or_create_by!(email: "owner@cove.test") do |u|
    u.name = "Olivia Owner"
    u.password = "password"
    u.terms_of_service = "1"
    u.confirmed_at = Time.current
  end

  admin = User.find_or_create_by!(email: "admin@cove.test") do |u|
    u.name = "Andy Admin"
    u.password = "password"
    u.terms_of_service = "1"
    u.confirmed_at = Time.current
  end

  member = User.find_or_create_by!(email: "member@cove.test") do |u|
    u.name = "Molly Member"
    u.password = "password"
    u.terms_of_service = "1"
    u.confirmed_at = Time.current
  end

  subscribed = User.find_or_create_by!(email: "subscribed@cove.test") do |u|
    u.name = "Sofia Subscriber"
    u.password = "password"
    u.terms_of_service = "1"
    u.confirmed_at = Time.current
  end

  superadmin = User.find_or_create_by!(email: "superadmin@cove.test") do |u|
    u.name = "Sydney Super"
    u.password = "password"
    u.terms_of_service = "1"
    u.confirmed_at = Time.current
  end

  team = Account.find_or_create_by!(name: "Cove Team", owner: owner) do |a|
    a.personal = false
  end

  team_owner = AccountUser.find_or_create_by!(account: team, user: owner)
  team_owner.update!(admin: true)

  team_admin = AccountUser.find_or_create_by!(account: team, user: admin)
  team_admin.update!(admin: true)

  AccountUser.find_or_create_by!(account: team, user: member)

  plan = Plan.find_or_create_by!(fake_processor_id: "cove_dev") do |p|
    p.name = "Cove Dev Plan"
    p.amount = 1900
    p.interval = "month"
  end

  subscribed_account = subscribed.personal_account
  subscribed_account.set_payment_processor :fake_processor, allow_fake: true
  unless subscribed_account.payment_processor&.subscribed?
    subscribed_account.payment_processor.subscribe(plan: plan.fake_processor_id)
  end

  Jumpstart.grant_system_admin!(superadmin)
end
