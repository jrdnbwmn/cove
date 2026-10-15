require "test_helper"
require "view_component/test_case"

class AddTileComponentTest < ViewComponent::TestCase
  test "renders a full-height tile with its label, icon, data attributes, and custom classes" do
    render_inline(AddTileComponent.new(
      text: "Add learner",
      data: {action: "click->ui-modal#open:prevent"},
      classes: "col-span-full"
    ))

    assert_selector "button[type='button'][data-action='click->ui-modal#open:prevent'].h-full.w-full.col-span-full"
    assert_selector "button.border-dashed.rounded-xl.focus-visible\\:outline-primary", text: "Add learner"
    assert_selector "svg.size-5"
  end
end
