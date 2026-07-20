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

  test "renders a submit button with its custom pending label" do
    render_inline(ButtonComponent.new(text: "Save changes", type: "submit", data: {disable_with: "Saving..."}))

    assert_selector "button[type='submit'] .when-enabled", text: "Save changes"
    assert_selector "button[type='submit'] .when-disabled", text: "Saving..."
    assert_selector "button[type='submit'] .when-disabled svg.animate-spin"
  end

  test "renders a submit button with the fallback pending label" do
    render_inline(ButtonComponent.new(text: "Save changes", type: "submit"))

    assert_selector "button[type='submit'] .when-disabled", text: "Working..."
  end

  test "does not render pending state markup for non-submit buttons" do
    render_inline(ButtonComponent.new(text: "Open menu", type: "button"))

    assert_no_selector ".when-enabled"
    assert_no_selector ".when-disabled"
  end
end
