require "test_helper"
require "view_component/test_case"

class PlanCardComponentTest < ViewComponent::TestCase
  test "renders a priced plan with its features and action content" do
    plan = plans(:personal)

    render_inline(PlanCardComponent.new(plan: plan)) { "Start trial" }

    assert_text plan.name
    assert_text "$19"
    assert_text "/month"
    assert_text "Unlimited access"
    assert_text "Start trial"
  end

  test "renders the contact-us price for contact plans" do
    render_inline(PlanCardComponent.new(plan: plans(:enterprise)))

    assert_text "Let's Talk"
  end

  test "renders the unit label when a plan charges per unit" do
    render_inline(PlanCardComponent.new(plan: plans(:per_seat)))

    assert_text "/ seat"
    assert_text "/month"
  end

  test "renders the priced plan preview" do
    render_preview(:priced_plan)

    assert_text "Starter"
    assert_text "Start trial"
  end
end
