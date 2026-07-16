require "test_helper"
require "view_component/test_case"

class BreadcrumbComponentTest < ViewComponent::TestCase
  test "renders a current page in an accessible breadcrumb trail" do
    render_inline(BreadcrumbComponent.new(items: [
      {label: "Home", href: "/"},
      {label: "Projects", href: "/projects"},
      {label: "Roadmap"}
    ]))

    assert_selector "nav[aria-label='Breadcrumb']"
    assert_selector "a[href='/projects']", text: "Projects"
    assert_selector "[aria-current='page']", text: "Roadmap"
  end

  test "renders the background preview" do
    render_preview(:with_background)

    assert_text "Project settings"
  end
end
