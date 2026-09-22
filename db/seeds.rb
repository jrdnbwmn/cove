# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

if Rails.env.local?
  # AIDEV-NOTE: User creation creates one non-personal family. Seed membership
  # moves must archive the generated family before joining another one.

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

  tester = User.find_or_create_by!(email: "tester@cove.test") do |u|
    u.name = "Tina Tester"
    u.password = "password"
    u.terms_of_service = "1"
    u.confirmed_at = Time.current
  end

  owner.create_default_account unless owner.family
  admin.create_default_account unless admin.family
  subscribed.create_default_account unless subscribed.family
  tester.create_default_account unless tester.family

  family = owner.family
  family.update!(name: "Cove Family")

  if admin.family != family
    old_family = admin.family
    old_family.account_users.destroy_all
    old_family.archive!
    AccountUser.create!(account: family, user: admin, admin: true)
  end

  features = ["Placeholder feature"]

  plan = Plan.find_or_create_by!(fake_processor_id: "premium_monthly") do |p|
    p.name = "Premium"
    p.amount = 1200
    p.interval = "month"
    p.trial_period_days = 0
    p.details = {features: features}
  end
  plan.update!(amount: 1200)

  yearly_plan = Plan.find_or_create_by!(fake_processor_id: "premium_yearly") do |p|
    p.name = "Premium"
    p.amount = 12000
    p.interval = "year"
    p.trial_period_days = 0
    p.details = {features: features}
  end
  yearly_plan.update!(amount: 12000)

  subscribed_account = subscribed.family
  subscribed_account.set_payment_processor :fake_processor, allow_fake: true
  unless subscribed_account.payment_processor&.subscribed?
    subscribed_account.payment_processor.subscribe(plan: plan.fake_processor_id)
  end

  tester.family.update!(
    complimentary_premium: true,
    complimentary_premium_note: "Dev seed: complimentary Premium tester"
  )

  Jumpstart.grant_system_admin!(superadmin)
end
