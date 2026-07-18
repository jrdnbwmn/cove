require "test_helper"
require "view_component/test_case"

class ButtonComponentTest < ViewComponent::TestCase
  test "renders the primary button with design tokens" do
    render_inline(ButtonComponent.new(text: "Click me"))

    assert_selector "button.bg-primary"
    assert_selector "button.text-primary-foreground"
    assert_selector "button.rounded-\\[var\\(--radius\\)\\]"
  end

  test "renders the default preview" do
    render_preview(:default)

    assert_text "Primary Button"
    assert_selector "button.bg-primary.text-primary-foreground"
  end

  test "renders an external link securely" do
    render_inline(ButtonComponent.new(text: "Read the Docs", href: "https://example.com", target: "_blank"))

    assert_selector 'a[href="https://example.com"][target="_blank"][rel~="noopener"]', text: "Read the Docs"
  end
end
