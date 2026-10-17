require "test_helper"

class ModalTriggerButtonTest < ActionView::TestCase
  test "a row trigger is a muted borderless button with a plus and accessible text" do
    render "application/modal_trigger_button", text: "Add class", row: true

    assert_select "button[class~='text-muted-foreground!'].border-0[data-action='click->ui-modal#open:prevent']", text: "Add class" do
      assert_select "svg"
    end
    assert_select "button.border-dashed", count: 0
  end

  test "a lazy row trigger keeps its source without a full height tile wrapper" do
    render "application/lazy_modal", src: "/classes/new", text: "Add class", row: true

    assert_select "[data-ui-modal-turbo-frame-src-value='/classes/new']" do
      assert_select "button[class~='text-muted-foreground!']", text: "Add class"
    end
    assert_select "[data-controller~='ui-modal'].h-full", count: 0
    assert_select "turbo-frame", count: 0
  end

  test "the default trigger retains its button options" do
    render "application/modal_trigger_button", text: "Add class", button: {variant: :outline}

    assert_select "button.border.bg-transparent[data-action='click->ui-modal#open:prevent']", text: "Add class"
    assert_select "button.border-dashed", count: 0
  end

  test "the lazy tile retains its dashed button and full height wrapper" do
    render "application/lazy_modal", src: "/classes/new", text: "Add class", tile: true

    assert_select "[data-controller~='ui-modal'].h-full" do
      assert_select "button.border-dashed[data-action='click->ui-modal#open:prevent']", text: /Add class/
    end
  end
end
