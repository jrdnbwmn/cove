require "test_helper"
require "view_component/test_case"

class PasswordComponentTest < ViewComponent::TestCase
  test "renders a labelled password input" do
    render_inline(PasswordComponent.new(label: "Password", name: "user[password]"))

    assert_selector "input[type='password'][name='user[password]']"
    assert_text "Password"
  end

  test "renders the requirements preview" do
    render_preview(:requirements)

    assert_text "At least 8 characters"
  end
end
