require "test_helper"

class PlanPricingHelperTest < ActionView::TestCase
  include PlanPricingHelper

  def current_account
    Current.account
  end

  setup do
    Current.reset
  end

  teardown do
    Current.reset
  end

  test "shows yearly plans as rounded monthly equivalents" do
    assert_equal "$10/mo", monthly_equivalent(plans(:premium_yearly))
    assert_equal "$7.50/mo", monthly_equivalent(Plan.new(amount: 9000, interval: "year"))
  end

  test "shows the signed-in Free family's raised learner capacity" do
    account = accounts(:one)
    account.update!(learner_limit: 20)
    Current.account = account

    assert_equal 20, pricing_learner_limit
  end

  test "shows the signed-in paid family's raised learner capacity" do
    account = accounts(:subscribed)
    account.update!(learner_limit: 20)
    Current.account = account

    assert_equal 20, pricing_learner_limit
  end

  test "shows the signed-in complimentary family's raised learner capacity" do
    account = accounts(:complimentary)
    account.update!(learner_limit: 20)
    Current.account = account

    assert_equal 20, pricing_learner_limit
  end

  test "shows the default learner capacity of fifteen when signed out" do
    assert_equal 15, pricing_learner_limit
  end
end
