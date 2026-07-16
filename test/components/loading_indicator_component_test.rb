require "test_helper"
require "view_component/test_case"

class LoadingIndicatorComponentTest < ViewComponent::TestCase
  test "renders a spinner by default" do
    render_inline(LoadingIndicatorComponent.new)

    assert_selector "svg"
  end

  test "renders the primary color using design tokens" do
    render_inline(LoadingIndicatorComponent.new(color: :primary))

    assert_selector ".text-primary"
  end

  test "renders the progress preview" do
    render_preview(:progress)

    assert_selector "[style*='width']"
  end
end
