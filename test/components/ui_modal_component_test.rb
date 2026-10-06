require "test_helper"
require "view_component/test_case"

class UiModalComponentTest < ViewComponent::TestCase
  test "renders a collision-free modal controller" do
    render_inline(UiModalComponent.new(title: "Confirm action", trigger_text: "Open modal", prevent_dismiss: true)) do
      "Modal content"
    end

    assert_selector "[data-controller~='ui-modal']"
    assert_selector "[data-controller~='ui-modal-unsaved-changes']"
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

    assert_selector "[data-controller~='ui-modal'] button[data-action='click->ui-modal#open:prevent']", text: "Add student", count: 1
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

  test "uses a full-height phone sheet and a sized desktop dialog" do
    render_inline(UiModalComponent.new(size: :md, title: "Add student")) { "Modal content" }

    assert_selector "dialog.h-dvh.max-h-dvh.w-full.max-w-full.rounded-none.sm\\:h-auto.sm\\:max-w-md.sm\\:rounded-xl"
    assert_selector "dialog > div.h-full.overflow-y-auto"
  end

  test "keeps larger modal widths behind the small-screen breakpoint" do
    render_inline(UiModalComponent.new(size: :lg, title: "Add student")) { "Modal content" }

    assert_selector "dialog.sm\\:max-w-lg"
    assert_no_selector "dialog[class*='max-w-[100vw-2rem]']"
  end
end
