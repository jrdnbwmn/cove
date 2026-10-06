require "test_helper"
require "view_component/test_case"

class PageHeaderComponentTest < ViewComponent::TestCase
  test "renders the title as an h1" do
    render_inline(PageHeaderComponent.new(title: "Students"))

    assert_selector "h1", text: "Students"
  end

  test "renders the description when given" do
    render_inline(PageHeaderComponent.new(title: "Students", description: "The people learning with you."))

    assert_selector "p", text: "The people learning with you."
  end

  test "omits the description when none is given" do
    render_inline(PageHeaderComponent.new(title: "Students"))

    assert_no_selector "p"
  end

  test "puts the description directly under the title, before the actions, so phones read title, description, actions" do
    render_inline(PageHeaderComponent.new(title: "Students", description: "The people learning with you.")) do |component|
      component.with_primary_action { '<button type="button">Add student</button>'.html_safe }
    end

    assert_selector "h1 + p", text: "The people learning with you."
    assert_selector "h1 + p ~ [data-page-header-actions] button", text: "Add student"
  end

  test "renders the primary action" do
    render_inline(PageHeaderComponent.new(title: "Students")) do |component|
      component.with_primary_action { '<button type="button">Add student</button>'.html_safe }
    end

    assert_selector "button", text: "Add student"
  end

  test "renders secondary actions inline and in the more actions menu" do
    render_inline(PageHeaderComponent.new(title: "Students")) do |component|
      component.with_secondary_action { '<button type="button">Export</button>'.html_safe }
      component.with_secondary_action { '<button type="button">Print</button>'.html_safe }
    end

    assert_selector "button", text: "Export", count: 2, visible: :all
    assert_selector "button", text: "Print", count: 2, visible: :all
    assert_selector "button[aria-label='More actions']"
  end

  test "raises when given more than two secondary actions" do
    component = PageHeaderComponent.new(title: "Students")
    component.with_secondary_action { "First" }
    component.with_secondary_action { "Second" }

    assert_raises(ArgumentError) { component.with_secondary_action { "Third" } }
  end

  test "omits the actions wrapper when no actions are given" do
    render_inline(PageHeaderComponent.new(title: "Students"))

    assert_no_selector "[data-page-header-actions]"
  end
end
