require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  SEEDS_FILE = Rails.root.join("db/seeds.rb")
  DEMO_EMAILS = "%@cove.test"

  %w[staging production].each do |environment|
    test "#{environment} does not create demo seed data" do
      environment_inquirer = ActiveSupport::EnvironmentInquirer.new(environment)

      assert_no_difference [
        -> { User.count },
        -> { Account.count },
        -> { AccountUser.count },
        -> { Plan.count }
      ] do
        Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }
      end

      assert_not User.where("email LIKE ?", DEMO_EMAILS).exists?
    end
  end

  test "development seeds Premium monthly and yearly with no trial" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }
    Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }

    seeded = Plan.where(fake_processor_id: %w[premium_monthly premium_yearly])
    assert_equal 2, seeded.count

    monthly = seeded.visible.where(name: "Premium", interval: "month", fake_processor_id: "premium_monthly")
    yearly = seeded.visible.where(name: "Premium", interval: "year", fake_processor_id: "premium_yearly")
    assert_equal 1, monthly.count
    assert_equal 1, yearly.count
    assert_equal 900, monthly.first.amount
    assert_equal 8400, yearly.first.amount
    assert_equal [0, 0], [monthly.first.trial_period_days, yearly.first.trial_period_days]

    assert_not Plan.exists?(fake_processor_id: "cove_dev")
    assert_equal "premium_monthly", User.find_by!(email: "subscribed@cove.test").family.payment_processor.subscription.processor_plan
  end

  test "development seeds one two-parent family and one flat-rate subscribed family" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }

    family = Account.find_by!(name: "Cove Family")
    assert_equal 2, family.account_users_count
    assert_equal 2, family.parents.count
    assert_equal 1, User.find_by!(email: "subscribed@cove.test").family.payment_processor.subscription.quantity
  end

  test "development seeds one complimentary Premium tester family without billing records" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }
    Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }

    testers = User.where(email: "tester@cove.test")
    assert_equal 1, testers.count

    tester = testers.sole
    assert_equal "Tina Tester", tester.name
    assert tester.valid_password?("password")
    assert_not_nil tester.confirmed_at
    assert_not_nil tester.accepted_terms_at

    family = tester.family
    assert family.complimentary_premium?
    assert_equal "Dev seed: complimentary Premium tester", family.complimentary_premium_note
    assert_empty family.pay_customers
    assert_empty family.pay_subscriptions
  end
end
