require "test_helper"
require "view_component/test_case"

class UiModalComponentTest < ViewComponent::TestCase
  test "renders a collision-free modal controller" do
    render_inline(UiModalComponent.new(title: "Confirm action", trigger_text: "Open modal", prevent_dismiss: true)) do
      "Modal content"
    end

    assert_selector "[data-controller='ui-modal']"
    assert_selector "dialog[data-ui-modal-target='dialog']"
    assert_selector "[data-ui-modal-prevent-dismiss-value='true']"
    assert_text "Confirm action"
    assert_text "Modal content"
  end

  test "renders the confirmation preview" do
    render_preview(:confirmation)

    assert_text "Delete project?"
    assert_selector "button", text: "Cancel"
    assert_selector "button", text: "Delete project"
  end
end
