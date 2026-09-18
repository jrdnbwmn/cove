require "test_helper"

class Madmin::PlansTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "admin can't delete a plan that has subscribers" do
    plan = plans(:personal)
    pay_customers(:subscribed).subscriptions.create!(
      name: "default", processor_id: "sub_x", processor_plan: plan.stripe_id, quantity: 1, status: "active"
    )

    assert_no_difference "Plan.count" do
      delete madmin_plan_path(plan)
    end

    assert_redirected_to madmin_plan_path(plan)
    follow_redirect!
    assert_response :success
    assert_includes response.body, CGI.escapeHTML("This plan has subscribers, so it can't be deleted. Hide it instead.")
  end

  test "admin can delete a plan with no subscribers" do
    plan = plans(:business)

    assert_difference "Plan.count", -1 do
      delete madmin_plan_path(plan)
    end

    assert_not Plan.exists?(plan.id)
    assert_redirected_to madmin_plans_path
  end
end
