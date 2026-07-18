require "test_helper"
require "view_component/test_case"

class SelectComponentTest < ViewComponent::TestCase
  test "renders a labelled select control without inline styles" do
    render_inline(SelectComponent.new(label: "Team size", name: "account[team_size]", options: [["1-5", "small"], ["6-20", "medium"]]))

    assert_selector "select[name='account[team_size]']"
    assert_no_selector "select[style]"
    assert_text "Team size"
  end

  test "renders the multiple selection preview" do
    render_preview(:multiple)

    assert_selector "select[multiple]"
  end
end
