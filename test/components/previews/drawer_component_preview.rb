class DrawerComponentPreview < ViewComponent::Preview
  def default
    render(Drawer::Component.new(title: "Drawer title", trigger_text: "Open Drawer")) do
      "Drawer content here."
    end
  end

  def with_footer
    component = Drawer::Component.new(snap_points: :large, title: "Edit profile", trigger_text: "Open Settings")
    component.with_footer { "Save changes" }
    render(component) { "Content that can expand to different heights." }
  end

  def with_custom_trigger
    component = Drawer::Component.new(snap_points: :large, title: "Menu")
    component.with_trigger do
      '<button type="button" aria-label="Open menu" data-action="drawer#show:prevent" class="flex size-12 items-center justify-center rounded-full bg-white text-neutral-700 shadow-lg">Menu</button>'.html_safe
    end
    render(component) { "Custom icon-only trigger, used for the mobile floating menu button." }
  end
end
