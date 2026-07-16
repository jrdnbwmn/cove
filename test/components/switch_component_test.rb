require "test_helper"
require "view_component/test_case"

class SwitchComponentTest < ViewComponent::TestCase
  test "renders a labelled switch" do
    render_inline(SwitchComponent.new(label: "Enable weekly summary", name: "preferences[weekly_summary]"))

    assert_selector "input[type='checkbox'][name='preferences[weekly_summary]']"
    assert_text "Enable weekly summary"
  end

  test "renders the checked preview" do
    render_preview(:checked)

    assert_selector "input[type='checkbox'][checked]"
  end
end
