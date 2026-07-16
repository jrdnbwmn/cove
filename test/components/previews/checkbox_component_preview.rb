class CheckboxComponentPreview < ViewComponent::Preview
  def default
    render CheckboxComponent.new(label: "Receive product updates", name: "preferences[product_updates]")
  end

  def checked
    render CheckboxComponent.new(label: "Receive product updates", name: "preferences[product_updates]", checked: true)
  end

  def error
    render CheckboxComponent.new(label: "Accept the terms", name: "terms", required: true, error: "You must accept the terms.")
  end

  def disabled
    render CheckboxComponent.new(label: "Enterprise controls", name: "enterprise", disabled: true, description: "Available on Enterprise plans.")
  end
end
