require "test_helper"
require "view_component/test_case"

class CheckboxComponentTest < ViewComponent::TestCase
  test "renders a labelled checkbox" do
    render_inline(CheckboxComponent.new(label: "Receive product updates", name: "preferences[product_updates]"))

    assert_selector "input[type='checkbox'][name='preferences[product_updates]']"
    assert_text "Receive product updates"
  end

  test "uses the Rails Blocks checkbox class" do
    render_inline(CheckboxComponent.new(label: "Receive product updates", name: "preferences[product_updates]"))

    assert_selector "input[type='checkbox'].rounded"
  end

  test "uses the application primary color tokens" do
    render_inline(CheckboxComponent.new(label: "Receive product updates"))

    assert_selector "input[type='checkbox'].accent-primary.text-primary.focus\\:ring-primary-foreground"
  end

  test "passes data attributes to the checkbox input" do
    render_inline(CheckboxComponent.new(label: "Receive product updates", data: {controller: "preferences", action: "change->preferences#save"}))

    assert_selector "input[data-controller='preferences'][data-action='change->preferences#save']"
  end

  test "renders a safe HTML label" do
    view_helpers = ActionController::Base.helpers
    label_html = view_helpers.safe_join(["I agree to the ", view_helpers.link_to("Terms of Service", "/terms")])

    render_inline(CheckboxComponent.new(label: "I agree to the Terms of Service", label_html:, name: "user[terms_of_service]"))

    assert_selector "label a[href='/terms']", text: "Terms of Service"
  end

  test "escapes the regular label" do
    render_inline(CheckboxComponent.new(label: "<strong>Receive product updates</strong>", name: "preferences[product_updates]"))

    assert_no_selector "label strong"
    assert_text "<strong>Receive product updates</strong>"
  end

  test "renders the error preview" do
    render_preview(:error)

    assert_text "You must accept the terms."
  end
end
