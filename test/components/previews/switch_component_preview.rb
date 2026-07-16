class SwitchComponentPreview < ViewComponent::Preview
  def default
    render SwitchComponent.new(label: "Enable weekly summary", name: "preferences[weekly_summary]")
  end

  def checked
    render SwitchComponent.new(label: "Enable weekly summary", name: "preferences[weekly_summary]", checked: true, show_icons: true)
  end

  def error
    render SwitchComponent.new(label: "Required setting", name: "required_setting", error: "This setting must be enabled.")
  end

  def disabled
    render SwitchComponent.new(label: "Admin controls", name: "admin_controls", disabled: true, description: "Managed by your account administrator.")
  end
end
