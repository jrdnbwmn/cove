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

  test "keeps the default trigger button when no trigger slot is given" do
    render_inline(UiModalComponent.new(title: "Confirm", trigger_text: "Open modal")) { "Modal content" }

    assert_selector "button[data-action='click->ui-modal#open:prevent']", text: "Open modal", count: 1
  end

  test "a caller-supplied button replaces the default trigger and opens the modal" do
    render_inline(UiModalComponent.new(title: "Add student", trigger_text: "Default text")) do |modal|
      modal.with_trigger { '<button data-action="click->ui-modal#open:prevent">Add student</button>'.html_safe }
      "Modal content"
    end

    assert_selector "[data-controller='ui-modal'] button[data-action='click->ui-modal#open:prevent']", text: "Add student", count: 1
    assert_no_text "Default text"
    assert_selector "dialog[data-ui-modal-target='dialog']", visible: :all
  end

  test "renders the custom trigger preview" do
    render_preview(:custom_trigger)

    assert_selector "button[data-action='click->ui-modal#open:prevent']", text: "Add student", count: 1
    assert_selector "button.bg-primary, button[class*='primary']", text: "Add student"
  end

  test "renders the confirmation preview" do
    render_preview(:confirmation)

    assert_text "Delete project?"
    assert_selector "button", text: "Cancel"
    assert_selector "button", text: "Delete project"
  end
end
