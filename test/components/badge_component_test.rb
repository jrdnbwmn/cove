require "test_helper"
require "view_component/test_case"

class BadgeComponentTest < ViewComponent::TestCase
  test "renders a badge with text" do
    render_inline(BadgeComponent.new(text: "Published", variant: :green))

    assert_text "Published"
  end

  test "renders the removable preview" do
    render_preview(:removable)

    assert_selector "button"
  end
end
