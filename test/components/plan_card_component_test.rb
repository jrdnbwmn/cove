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

  test "renders a Free card without a plan" do
    render_inline(PlanCardComponent.new(
      name: "Free",
      description: "For families getting started.",
      price_text: "Free",
      features: ["1 student"]
    )) { "Current plan" }

    assert_text "Free"
    assert_text "For families getting started."
    assert_text "1 student"
    assert_text "Current plan"
  end

  test "renders a custom yearly-equivalent price and billing note without the plan interval" do
    render_inline(PlanCardComponent.new(
      plan: plans(:personal),
      price_text: "$7/mo",
      price_note: "Billed $84/year"
    ))

    assert_text "$7/mo"
    assert_text "Billed $84/year"
    assert_no_text "/month"
  end

  test "renders supplied features instead of a plan's features" do
    render_inline(PlanCardComponent.new(plan: plans(:personal), features: ["Up to 5 students"]))

    assert_text "Up to 5 students"
    assert_no_text "Unlimited access"
  end

  test "renders the priced plan preview" do
    render_preview(:priced_plan)

    assert_text "Starter"
    assert_text "Choose plan"
  end

  test "renders the Free plan preview" do
    render_preview(:free_plan)

    assert_text "Free"
    assert_text "1 student"
  end

  test "renders the yearly-equivalent plan preview" do
    render_preview(:yearly_equivalent_plan)

    assert_text "$7/mo"
    assert_text "Billed $84/year"
  end
end
