require "test_helper"
require "view_component/test_case"

class SidebarComponentTest < ViewComponent::TestCase
  test "renders a collapsible sidebar with navigation items" do
    render_inline(SidebarComponent.new(storage_key: "projectSidebar")) do |sidebar|
      sidebar.with_item(label: "Projects", href: "/projects", active: true)
    end

    assert_selector "[data-controller='sidebar']"
    assert_selector "a[href='/projects'][aria-label='Projects']"
  end

  test "renders the sections preview" do
    render_preview(:sections)

    assert_text "Main content"
  end

  test "the inset variant has no sidebar border on desktop or mobile" do
    render_inline(SidebarComponent.new(variant: :inset)) do |sidebar|
      sidebar.with_item(label: "Home", href: "/", active: true)
    end

    desktop_classes = page.find("[data-sidebar-target='desktopSidebar']")[:class]
    mobile_classes = page.find("[data-sidebar-target='mobilePanel']")[:class]

    assert_includes desktop_classes, "bg-background"
    assert_includes mobile_classes, "bg-background"
    assert_no_match(/\bborder-r\b/, desktop_classes)
    assert_no_match(/\bborder-r\b/, mobile_classes)
  end

  test "existing bordered variant keeps its border unchanged" do
    render_inline(SidebarComponent.new(variant: :bordered)) do |sidebar|
      sidebar.with_item(label: "Home", href: "/")
    end

    desktop_classes = page.find("[data-sidebar-target='desktopSidebar']")[:class]
    assert_match(/border-r border-neutral-200/, desktop_classes)
  end

  test "existing minimal variant keeps its borderless surface unchanged" do
    render_inline(SidebarComponent.new(variant: :minimal)) do |sidebar|
      sidebar.with_item(label: "Home", href: "/")
    end

    desktop_classes = page.find("[data-sidebar-target='desktopSidebar']")[:class]
    assert_includes desktop_classes, "bg-white"
    assert_no_match(/\bborder-r\b/, desktop_classes)
  end

  test "the collapsed nav link gets aria-current when its item is active, not when inactive" do
    render_inline(SidebarComponent.new) do |sidebar|
      sidebar.with_item(label: "Home", href: "/", active: true)
      sidebar.with_item(label: "Settings", href: "/settings", active: false)
    end

    assert_selector "a[href='/'][aria-current='page']"
    assert_no_selector "a[href='/settings'][aria-current]"
  end

  test "the expanded item component gets aria-current when active, not when inactive" do
    render_inline(SidebarComponent::ItemComponent.new(label: "Home", href: "/", active: true))
    assert_selector "a[href='/'][aria-current='page']"
  end

  test "the expanded item component omits aria-current when inactive" do
    render_inline(SidebarComponent::ItemComponent.new(label: "Home", href: "/", active: false))
    assert_no_selector "a[aria-current]"
  end

  test "renders a caller-supplied mobile toggle indicator" do
    render_inline(SidebarComponent.new) do |sidebar|
      sidebar.with_mobile_toggle_indicator { "<span class=\"mobile-dot\"></span>".html_safe }
      sidebar.with_item(label: "Home", href: "/")
    end

    assert_selector "button[aria-label='Open sidebar'] .mobile-dot"
  end

  test "omits the mobile toggle indicator by default" do
    render_inline(SidebarComponent.new) do |sidebar|
      sidebar.with_item(label: "Home", href: "/")
    end

    assert_no_selector ".mobile-dot"
  end
end
