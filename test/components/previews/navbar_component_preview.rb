class NavbarComponentPreview < ViewComponent::Preview
  def default
    navbar = NavbarComponent.new
    navbar.with_item(label: "Dashboard", href: "/dashboard")
    navbar.with_item(label: "Projects", href: "/projects")
    render navbar
  end

  def dropdown
    navbar = NavbarComponent.new
    navbar.with_item(label: "Dashboard", href: "/dashboard")
    navbar.with_item(label: "Resources", dropdown: true, content_id: "resources")
    navbar.with_dropdown_content(id: "resources", columns: 2) { "Guides and support" }
    render navbar
  end

  def transparent
    navbar = NavbarComponent.new(variant: :transparent)
    navbar.with_item(label: "Features", href: "/features")
    navbar.with_item(label: "Pricing", href: "/pricing")
    render navbar
  end
end
