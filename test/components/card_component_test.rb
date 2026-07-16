require "test_helper"
require "view_component/test_case"

class CardComponentTest < ViewComponent::TestCase
  test "renders card sections with dividers" do
    render_inline(CardComponent.new(divide: true)) do |card|
      card.with_header { "Project summary" }
      card.with_body { "Three tasks are ready." }
      card.with_footer { "View project" }
    end

    assert_text "Project summary"
    assert_text "Three tasks are ready."
    assert_text "View project"
    assert_selector "div.divide-y"
  end

  test "renders the sections preview" do
    render_preview(:with_sections)

    assert_text "Project summary"
  end
end
