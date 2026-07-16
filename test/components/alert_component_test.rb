require "test_helper"
require "view_component/test_case"

class AlertComponentTest < ViewComponent::TestCase
  test "renders an alert with title and description" do
    render_inline(AlertComponent.new(title: "Saved", description: "Your changes have been applied."))

    assert_text "Saved"
    assert_text "Your changes have been applied."
  end

  test "renders the error preview" do
    render_preview(:error)

    assert_text "Something went wrong"
  end
end
