require "test_helper"
require "view_component/test_case"

class RadioComponentTest < ViewComponent::TestCase
  test "renders a labelled radio option" do
    render_inline(RadioComponent.new(label: "Starter", name: "plan", value: "starter"))

    assert_selector "input[type='radio'][name='plan'][value='starter']"
    assert_text "Starter"
  end

  test "uses the application primary color tokens" do
    render_inline(RadioComponent.new(label: "Starter"))

    assert_selector "input[type='radio'].accent-primary.text-primary.focus\\:ring-primary-foreground"
  end

  test "renders the disabled preview" do
    render_preview(:disabled)

    assert_selector "input[type='radio'][disabled]"
  end
end
