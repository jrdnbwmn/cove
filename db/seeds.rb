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

  [["Maya", "3rd grade"], ["Theo", "Pre-K"]].each do |name, grade_level|
    family.learners.find_or_create_by!(name: name) { |learner| learner.grade_level = grade_level }
  end

  maya = family.learners.find_by!(name: "Maya")
  theo = family.learners.find_by!(name: "Theo")

  algebra = family.courses.find_or_create_by!(name: "Algebra 1") { |course| course.subject = "Math" }
  piano = family.courses.find_or_create_by!(name: "Piano") { |course| course.subject = "Arts" }
  family.courses.find_or_create_by!(name: "Nature study")

  [[algebra, maya], [algebra, theo], [piano, maya]].each do |course, learner|
    course.enrollments.find_or_create_by!(learner: learner)
  end

  features = ["Placeholder feature"]

  seed_premium_plan = ->(fake_processor_id:, interval:, amount:) do
    plan = Plan.find_or_create_by!(fake_processor_id: fake_processor_id) do |p|
      p.name = "Premium"
      p.amount = amount
      p.interval = interval
      p.trial_period_days = 0
      p.details = {features: features}
    end
    plan.update!(amount: amount)
    plan
  end

  plan = seed_premium_plan.call(fake_processor_id: "premium_monthly", interval: "month", amount: 1200)
  seed_premium_plan.call(fake_processor_id: "premium_yearly", interval: "year", amount: 12000)

  subscribed_account = subscribed.family
  subscribed_account.set_payment_processor :fake_processor, allow_fake: true
  unless subscribed_account.payment_processor&.subscribed?
    subscribed_account.payment_processor.subscribe(plan: plan.fake_processor_id)
  end

  tester.family.update!(
    complimentary_premium: true,
    complimentary_premium_note: "Dev seed: complimentary Premium tester"
  )

  seed_scenario_family = ->(scenario, family_name) do
    User.transaction do
      user = User.find_or_initialize_by(email: "#{scenario}@cove.test")
      new_user = user.new_record?
      if new_user
        user.assign_attributes(name: family_name, password: "password", terms_of_service: "1", confirmed_at: Time.current)
        user.save!
      end
      user.create_default_account unless user.family
      scenario_family = user.family
      scenario_family.update!(name: family_name) if new_user
      next if !new_user && scenario_family.school_year

      year = SchoolYear.create_default_for!(scenario_family)
      next if scenario == "new"

      today = scenario_family.today
      calendar_year = today.year
      calendar_year -= 1 if today < SchoolYear.default_starts_on(calendar_year)
      starts_on = SchoolYear.default_starts_on(calendar_year)

      # AIDEV-NOTE: Historical demo scenarios intentionally bypass past-day protections.
      # Replace signup's year only on initialization; reseeding preserves parents' edits.
      year.update_columns(starts_on: starts_on, ends_on: SchoolYear.default_ends_on(calendar_year), school_weekdays: [1, 2, 3, 4, 5], weekday_history: [])
      year.breaks.delete_all
      time_off = SchoolYear.default_breaks_for(calendar_year).map do |name, first, last|
        {name: name, starts_on: first, ends_on: last, source: "default"}
      end
      time_off << {name: "Family day", starts_on: starts_on, ends_on: starts_on, source: "added"} if today > starts_on
      year.breaks.insert_all!(time_off)
      first_school_day = (starts_on..year.ends_on).find { |day| year.school_day?(day) }
      year.update_columns(tracked_from: first_school_day)
    end
  end
  [["new", "New Family"], ["midyear", "Mid-year Family"], ["away", "Away Family"]].each do |scenario, family_name|
    seed_scenario_family.call(scenario, family_name)
  end

  Jumpstart.grant_system_admin!(superadmin)
end
