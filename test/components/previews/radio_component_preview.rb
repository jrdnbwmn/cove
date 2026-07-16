class RadioComponentPreview < ViewComponent::Preview
  def default
    render RadioComponent.new(label: "Starter", name: "plan", value: "starter")
  end

  def selected
    render RadioComponent.new(label: "Team", name: "plan", value: "team", checked: true, description: "For small, collaborative teams.")
  end

  def disabled
    render RadioComponent.new(label: "Enterprise", name: "plan", value: "enterprise", disabled: true)
  end

  def error
    render RadioComponent.new(label: "Select a plan", name: "plan", value: "starter", error: "Choose a plan to continue.")
  end
end
