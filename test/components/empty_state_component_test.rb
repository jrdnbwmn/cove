require "test_helper"
require "view_component/test_case"

class EmptyStateComponentTest < ViewComponent::TestCase
  test "renders the required title" do
    render_inline(EmptyStateComponent.new(title: "No projects yet"))

    assert_text "No projects yet"
  end

  test "renders description when given" do
    render_inline(EmptyStateComponent.new(title: "No projects yet", description: "Create your first project to get started."))

    assert_text "Create your first project to get started."
  end

  test "omits icon backdrop when no icon slot is given" do
    render_inline(EmptyStateComponent.new(title: "No projects yet"))

    assert_no_selector "[aria-hidden='true']"
  end

  test "renders icon backdrop when icon slot is given" do
    render_inline(EmptyStateComponent.new(title: "No projects yet")) do |c|
      c.with_icon { "<svg></svg>".html_safe }
    end

    assert_selector "[aria-hidden='true']"
  end

  test "omits action row when no action slots are given" do
    render_inline(EmptyStateComponent.new(title: "No projects yet"))

    assert_no_selector ".flex.gap-3"
  end

  test "renders secondary action alone when only with_secondary_action is given" do
    render_inline(EmptyStateComponent.new(title: "No projects yet")) do |c|
      c.with_secondary_action { "Learn more" }
    end

    assert_text "Learn more"
  end

  test "heading_level 3 renders an h3" do
    render_inline(EmptyStateComponent.new(title: "No projects yet", heading_level: 3))

    assert_selector "h3", text: "No projects yet"
  end

  test "invalid size falls back to md classes" do
    render_inline(EmptyStateComponent.new(title: "No projects yet", size: :xl))

    assert_selector ".py-12"
  end

  test "bordered true adds a dashed border" do
    render_inline(EmptyStateComponent.new(title: "No projects yet", bordered: true))

    assert_selector ".border-dashed"
  end
end
