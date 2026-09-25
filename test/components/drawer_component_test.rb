require "test_helper"
require "view_component/test_case"

class DrawerComponentTest < ViewComponent::TestCase
  test "renders a dismissible drawer with the default trigger button" do
    render_inline(Drawer::Component.new(title: "Menu", trigger_text: "Open Drawer")) { "Drawer body" }

    assert_selector "[data-controller='drawer']"
    assert_selector "button[data-action='drawer#show:prevent']", text: "Open Drawer"
    assert_selector "dialog[data-drawer-target='dialog']"
    assert_text "Drawer body"
  end

  test "renders custom trigger markup instead of the default button" do
    component = Drawer::Component.new(title: "Menu")
    component.with_trigger { '<button aria-label="Open menu" data-action="drawer#show:prevent">Menu icon</button>'.html_safe }
    render_inline(component) { "Drawer body" }

    assert_selector "button[aria-label='Open menu']", text: "Menu icon"
    assert_no_text "Open Drawer"
  end

  test "renders the with_custom_trigger preview" do
    render_preview(:with_custom_trigger)

    assert_selector "button[aria-label='Open menu']"
  end
end
