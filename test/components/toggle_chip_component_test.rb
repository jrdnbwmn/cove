require "test_helper"
require "view_component/test_case"

class ToggleChipComponentTest < ViewComponent::TestCase
  test "a toggle chip is a labelled native checkbox with a name and value" do
    render_inline ToggleChipComponent.new(label: "Mon", name: "school_year[school_weekdays][]", id: "monday", value: 1)
    assert_selector "label[for='monday']", text: "Mon"
    assert_selector "input[type='checkbox'][id='monday'][name='school_year[school_weekdays][]'][value='1'].sr-only", visible: :all
    assert_no_selector "input.hidden", visible: :all
  end

  test "chips support checked and disabled states without JavaScript" do
    render_inline ToggleChipComponent.new(label: "Tue", checked: true, disabled: true)
    assert_selector "input[checked][disabled]", visible: :all
    assert_no_selector "[data-controller]"
  end

  test "chip errors are associated with the checkbox" do
    render_inline ToggleChipComponent.new(label: "Wed", id: "wednesday", error: "Choose at least one day.")
    assert_selector "input[aria-invalid='true'][aria-describedby='wednesday_error']", visible: :all
    assert_selector "#wednesday_error", text: "Choose at least one day."
  end

  test "chip inputs receive data attributes and labels are escaped" do
    render_inline ToggleChipComponent.new(label: "<b>Thu</b>", data: {action: "change->year#changed"})
    assert_selector "input[data-action='change->year#changed']", visible: :all
    assert_no_selector "b"
    assert_text "<b>Thu</b>"
  end

  test "chips use brand colors and visible keyboard focus" do
    render_inline ToggleChipComponent.new(label: "Fri")
    assert_includes rendered_content, "peer-checked:bg-primary"
    assert_includes rendered_content, "peer-checked:text-primary-foreground"
    assert_includes rendered_content, "peer-focus-visible:ring-primary"
  end
end
