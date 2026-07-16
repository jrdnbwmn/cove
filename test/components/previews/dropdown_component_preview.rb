class DropdownComponentPreview < ViewComponent::Preview
  def default
    component = DropdownComponent.new(trigger_text: "Account")
    component.with_item_link(text: "Profile", href: "#")
    component.with_item_link(text: "Settings", href: "#")
    component.with_item_divider
    component.with_item_button(text: "Sign out", destructive: true)
    render component
  end

  def grouped
    component = DropdownComponent.new(trigger_text: "Workspace", placement: "bottom-end")
    component.with_item_label(text: "Workspace")
    component.with_item_link(text: "Overview", href: "#")
    component.with_item_link(text: "Members", href: "#")
    render component
  end
end
