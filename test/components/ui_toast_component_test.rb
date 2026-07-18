require "test_helper"
require "view_component/test_case"

class UiToastComponentTest < ViewComponent::TestCase
  test "renders a namespaced toast container" do
    render_inline(UiToastComponent.new(position: "bottom-right", limit: 4))

    assert_selector "[data-controller='ui-toast']"
    assert_selector "[data-ui-toast-position-value='bottom-right']"
    assert_selector "[data-ui-toast-limit-value='4']"
  end

  test "renders the bottom right preview" do
    render_preview(:bottom_right)

    assert_selector "[data-ui-toast-position-value='bottom-right']"
  end

  test "renders a trigger in the default preview" do
    render_preview(:default)

    assert_selector "button[data-controller='toast-preview'][data-action='click->toast-preview#show']", text: "Show toast"
  end
end
