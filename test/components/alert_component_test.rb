require "test_helper"
require "view_component/test_case"

class AlertComponentTest < ViewComponent::TestCase
  test "renders an alert with title and description" do
    render_inline(AlertComponent.new(title: "Saved", description: "Your changes have been applied."))

    assert_text "Saved"
    assert_text "Your changes have been applied."
  end

  test "renders a Lucide icon for a success alert" do
    render_inline(AlertComponent.new(title: "Saved", variant: :success))

    assert_selector "svg[class='size-[18px]']"
  end

  test "renders a custom icon instead of the variant icon" do
    render_inline(AlertComponent.new(title: "Saved", custom_icon: '<svg class="custom-icon"></svg>'))

    assert_selector "svg.custom-icon"
  end

  test "renders the error preview" do
    render_preview(:error)

    assert_text "Something went wrong"
  end
end
