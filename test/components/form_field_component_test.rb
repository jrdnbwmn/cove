require "test_helper"
require "view_component/test_case"

class FormFieldComponentTest < ViewComponent::TestCase
  test "renders a labeled required field with helper text" do
    render_inline(FormFieldComponent.new(
      label: "Display name",
      name: "profile[display_name]",
      helper_text: "Shown to collaborators.",
      required: true
    )) do |component|
      component.with_input do
        ActionController::Base.helpers.tag.input(type: "text", class: "form-control", name: "profile[display_name]", id: "profile_display_name")
      end
    end

    assert_selector "label[for='profile_display_name']", text: "Display name"
    assert_selector "span", text: "*"
    assert_selector "input.form-control#profile_display_name"
    assert_text "Shown to collaborators."
  end

  test "renders error and disabled field states" do
    render_inline(FormFieldComponent.new(
      label: "Email",
      name: "user[email]",
      error: "Email is invalid.",
      disabled: true
    )) do |component|
      component.with_input do
        ActionController::Base.helpers.tag.input(type: "email", class: "form-control error", name: "user[email]", id: "user_email", disabled: true)
      end
    end

    assert_selector "input.form-control.error[disabled]"
    assert_text "Email is invalid."
  end

  test "renders the default preview" do
    render_preview(:default)

    assert_selector "input.form-control#profile_display_name"
    assert_text "Display name"
  end

  test "renders the small preview" do
    render_preview(:small)

    assert_text "Small"
  end

  test "renders the medium preview" do
    render_preview(:medium)

    assert_text "Medium"
  end

  test "renders the large preview" do
    render_preview(:large)

    assert_text "Large"
  end

  test "renders the floating preview" do
    render_preview(:floating)

    assert_text "Floating"
  end

  test "renders the inline preview" do
    render_preview(:inline)

    assert_text "Inline"
  end
end
