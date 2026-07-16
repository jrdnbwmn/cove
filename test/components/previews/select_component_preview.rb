class SelectComponentPreview < ViewComponent::Preview
  OPTIONS = [["Starter", "starter"], ["Team", "team"], ["Enterprise", "enterprise"]].freeze

  def default
    render SelectComponent.new(label: "Plan", name: "subscription[plan]", options: OPTIONS)
  end

  def multiple
    render SelectComponent.new(label: "Project roles", name: "project[roles][]", options: OPTIONS, multiple: true, selected: ["starter", "team"])
  end

  def error
    render SelectComponent.new(label: "Plan", name: "subscription[plan]", options: OPTIONS, error: "Choose a plan to continue.")
  end

  def disabled
    render SelectComponent.new(label: "Billing interval", name: "subscription[interval]", options: [["Monthly", "monthly"]], disabled: true)
  end
end
