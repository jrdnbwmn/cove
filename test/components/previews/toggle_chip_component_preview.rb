class ToggleChipComponentPreview < ViewComponent::Preview
  def default
    render ToggleChipComponent.new(label: "Mon", name: "weekdays[]", value: 1)
  end

  def selected
    render ToggleChipComponent.new(label: "Tue", name: "weekdays[]", value: 2, checked: true)
  end

  def disabled
    render ToggleChipComponent.new(label: "Wed", name: "weekdays[]", value: 3, checked: true, disabled: true)
  end

  def error
    render ToggleChipComponent.new(label: "Thu", name: "weekdays[]", value: 4, error: "Choose at least one school day.")
  end
end
