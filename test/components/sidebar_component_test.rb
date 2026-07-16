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
end
