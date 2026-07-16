class SidebarComponentPreview < ViewComponent::Preview
  def default
    sidebar = SidebarComponent.new
    sidebar.with_item(label: "Dashboard", href: "/dashboard", active: true)
    sidebar.with_item(label: "Settings", href: "/settings")
    render sidebar.with_content("Main content")
  end

  def sections
    sidebar = SidebarComponent.new
    sidebar.with_item(label: "Dashboard", href: "/dashboard", active: true)
    sidebar.with_section(title: "Projects") do |section|
      section.with_item(label: "Roadmap", href: "/projects/roadmap", badge: "3")
      section.with_item(label: "Archive", href: "/projects/archive")
    end
    render sidebar.with_content("Main content")
  end

  def minimal
    sidebar = SidebarComponent.new(variant: :minimal, collapsible: false)
    sidebar.with_item(label: "Dashboard", href: "/dashboard", active: true)
    render sidebar.with_content("Main content")
  end
end
