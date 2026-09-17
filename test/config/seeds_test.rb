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

  test "development seeds one two-parent family and one flat-rate subscribed family" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    Rails.stub(:env, environment_inquirer) { load SEEDS_FILE }

    family = Account.find_by!(name: "Cove Family")
    assert_equal 2, family.account_users_count
    assert_equal 2, family.parents.count
    assert_equal 1, User.find_by!(email: "subscribed@cove.test").family.payment_processor.subscription.quantity
  end
end
