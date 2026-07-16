require "test_helper"
require "view_component/test_case"

class NavbarComponentTest < ViewComponent::TestCase
  test "renders navigation items with the navbar controller" do
    render_inline(NavbarComponent.new(variant: :transparent)) do |navbar|
      navbar.with_item(label: "Dashboard", href: "/dashboard")
    end

    assert_selector "nav[data-controller='navbar']"
    assert_selector "a[href='/dashboard']", text: "Dashboard"
  end

  test "renders the dropdown preview" do
    render_preview(:dropdown)

    assert_text "Resources"
  end
end
