class BreadcrumbComponentPreview < ViewComponent::Preview
  def default
    render BreadcrumbComponent.new(items: items)
  end

  def with_background
    render BreadcrumbComponent.new(items: items, separator: :chevron, variant: :with_background)
  end

  def with_icons
    render BreadcrumbComponent.new(items: items, variant: :with_icons)
  end

  private

  def items
    [
      {label: "Home", href: "/"},
      {label: "Projects", href: "/projects"},
      {label: "Project settings"}
    ]
  end
end
