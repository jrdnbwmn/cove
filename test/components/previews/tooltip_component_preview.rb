class TooltipComponentPreview < ViewComponent::Preview
  def default
    render TooltipComponent.new(text: "Helpful information").with_content(button("Hover for help"))
  end

  def keyboard_shortcut
    render TooltipComponent.new(text: "Open command menu", placement: "bottom", mac_kbd: "cmd K", non_mac_kbd: "Ctrl K").with_content(button("Command menu"))
  end

  def click_trigger_without_arrow
    render TooltipComponent.new(text: "Click to toggle this tooltip", trigger: "click", arrow: false).with_content(button("More information"))
  end

  private

  def button(text)
    ActionController::Base.helpers.button_tag(text, type: "button", class: "rounded-md border border-border px-3 py-2")
  end
end
