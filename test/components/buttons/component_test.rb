require "test_helper"
require "view_component/test_case"

class Buttons::ComponentTest < ViewComponent::TestCase
  test "renders the primary button with design tokens" do
    render_inline(Buttons::Component.new(text: "Click me"))

    assert_selector "button.bg-primary"
    assert_selector "button.text-primary-foreground"
    assert_selector "button.rounded-\\[var\\(--radius\\)\\]"
  end

  test "renders the default preview" do
    render_preview(:default)

    assert_text "Primary Button"
    assert_selector "button.bg-primary.text-primary-foreground"
  end
end
