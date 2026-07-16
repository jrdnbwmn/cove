require "test_helper"
require "view_component/test_case"

class UiTabsComponentTest < ViewComponent::TestCase
  test "renders tabs with the collision-free tabs controller" do
    render_inline(UiTabsComponent.new(variant: :underline)) do |tabs|
      tabs.with_tab(title: "Overview", id: "overview")
      tabs.with_tab(title: "Activity", id: "activity")
      tabs.with_panel { "Overview content" }
      tabs.with_panel { "Activity content" }
    end

    assert_selector "[data-controller='ui-tabs']"
    assert_selector "[role='tablist']"
    assert_selector "[role='tabpanel']", text: "Overview content"
  end

  test "renders the vertical preview" do
    render_preview(:vertical)

    assert_text "Activity content"
  end
end
