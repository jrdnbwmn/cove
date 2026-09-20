class PlanCardComponentPreview < ViewComponent::Preview
  def priced_plan
    render plan_card(plan: plan(name: "Starter", amount: 1900, features: ["Unlimited projects", "Email support"]))
  end

  def free_plan
    render PlanCardComponent.new(
      name: "Free",
      description: "For families getting started.",
      price_text: "Free",
      features: ["1 student"]
    ).with_content("Current plan")
  end

  def yearly_equivalent_plan
    render PlanCardComponent.new(
      plan: plan(name: "Premium", amount: 8400, features: ["Up to 5 students"]),
      price_text: "$7/mo",
      price_note: "Billed $84/year"
    ).with_content("Choose plan")
  end

  def contact_us_plan
    render PlanCardComponent.new(plan: plan(name: "Enterprise", contact_url: "mailto:sales@example.com"))
  end

  def per_unit_plan
    render plan_card(plan: plan(name: "Team", amount: 2500, unit_label: "seat", features: ["Shared workspace"]))
  end

  private

  def plan_card(plan:)
    PlanCardComponent.new(plan: plan).with_content("Choose plan")
  end

  def plan(name:, amount: 0, contact_url: nil, unit_label: nil, features: [])
    Plan.new(
      name: name,
      description: "A plan preview for billing pages.",
      amount: amount,
      interval: "month",
      interval_count: 1,
      contact_url: contact_url,
      unit_label: unit_label,
      details: {features: features}
    )
  end
end
