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
    assert_equal "$7/mo", monthly_equivalent(plans(:premium_yearly))
    assert_equal "$7.50/mo", monthly_equivalent(Plan.new(amount: 9000, interval: "year"))
  end

  test "uses the signed-in Premium Family student limit" do
    Current.account = accounts(:complimentary)

    assert_equal 10, premium_student_limit
  end

  test "does not advertise a Free Family stored student limit" do
    account = accounts(:one)
    account.update!(student_limit: 10)
    Current.account = account

    assert_equal Account.default_student_limit, premium_student_limit
  end

  test "uses the Account default when signed out" do
    assert_equal Account.default_student_limit, premium_student_limit
  end
end
