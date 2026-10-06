require "test_helper"
require "view_component/test_case"

class DropdownComponentTest < ViewComponent::TestCase
  test "renders a collision-free dropdown with menu items" do
    render_inline(DropdownComponent.new(trigger_text: "Account", placement: "bottom-end")) do |dropdown|
      dropdown.with_item_link(text: "Profile", href: "/profile")
    end

    assert_selector "[data-controller='ui-dropdown-popover']"
    assert_selector "[data-controller='ui-menu']"
    assert_selector "[data-ui-dropdown-popover-placement-value='bottom-end']"
    assert_selector "a[href='/profile']", text: "Profile"
  end

  test "renders the grouped preview" do
    render_preview(:grouped)

    assert_text "Workspace"
  end

  test "menu item icons render trusted markup but escape plain strings" do
    render_inline(DropdownComponent.new(trigger_text: "Actions")) do |dropdown|
      dropdown.with_item_link(text: "Safe", icon: "<svg data-safe></svg>".html_safe)
      dropdown.with_item_link(text: "Unsafe", icon: "<script data-unsafe></script>")
    end

    assert_selector "svg[data-safe]"
    assert_no_selector "script[data-unsafe]", visible: :all
  end
end
