class BadgeComponentPreview < ViewComponent::Preview
  def default
    render BadgeComponent.new(text: "Neutral")
  end

  def colors
    render BadgeComponent.new(text: "Published", variant: :green)
  end

  def dot
    render BadgeComponent.new(text: "Active", variant: :blue, dot: true)
  end

  def pill
    render BadgeComponent.new(text: "Beta", variant: :purple, pill: true)
  end

  def removable
    render BadgeComponent.new(text: "Filter: Active", variant: :neutral, removable: true)
  end
end
