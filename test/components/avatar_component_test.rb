require "test_helper"
require "view_component/test_case"

class AvatarComponentTest < ViewComponent::TestCase
  test "renders an accessible avatar with a fallback" do
    render_inline(AvatarComponent.new(alt: "Avery Stone", fallback: "AS"))

    assert_selector "span", text: "AS"
    assert_selector "span[role='img'][aria-label='Avery Stone']"
  end

  test "renders the avatar group preview" do
    render_preview(:group)

    assert_selector "div[role='group'][aria-label='Project members']"
  end
end
