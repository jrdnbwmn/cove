class UiTabsComponentPreview < ViewComponent::Preview
  def default
    render tabs_component
  end

  def vertical
    render tabs_component(orientation: :vertical, variant: :low_contrast)
  end

  def underline
    render tabs_component(variant: :underline)
  end

  private

  def tabs_component(**options)
    tabs = UiTabsComponent.new(**options)
    tabs.with_tab(title: "Overview", id: "overview")
    tabs.with_tab(title: "Activity", id: "activity")
    tabs.with_panel { "Overview content" }
    tabs.with_panel { "Activity content" }
    tabs
  end
end
