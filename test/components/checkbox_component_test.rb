require "test_helper"
require "view_component/test_case"

class CheckboxComponentTest < ViewComponent::TestCase
  test "renders a labelled checkbox" do
    render_inline(CheckboxComponent.new(label: "Receive product updates", name: "preferences[product_updates]"))

    assert_selector "input[type='checkbox'][name='preferences[product_updates]']"
    assert_text "Receive product updates"
  end

  test "renders the error preview" do
    render_preview(:error)

    assert_text "You must accept the terms."
  end
end
