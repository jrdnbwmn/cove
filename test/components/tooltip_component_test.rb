require "test_helper"
require "view_component/test_case"

class TooltipComponentTest < ViewComponent::TestCase
  test "wraps the trigger with the collision-free tooltip controller" do
    render_inline(TooltipComponent.new(text: "Helpful information", placement: "bottom")) do
      "Hover for help"
    end

    assert_selector "[data-controller='ui-tooltip']"
    assert_selector "[data-ui-tooltip-content='Helpful information']"
    assert_text "Hover for help"
  end

  test "renders the keyboard shortcut preview" do
    render_preview(:keyboard_shortcut)

    assert_text "Command menu"
  end
end
