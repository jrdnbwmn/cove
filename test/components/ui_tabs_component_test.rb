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

  test "default mode is unaffected and still renders panel-switching tabs" do
    render_inline(UiTabsComponent.new(mode: :panels, variant: :underline)) do |tabs|
      tabs.with_tab(title: "Overview", id: "overview")
      tabs.with_tab(title: "Activity", id: "activity")
      tabs.with_panel { "Overview content" }
      tabs.with_panel { "Activity content" }
    end

    assert_selector "[data-controller='ui-tabs']"
    assert_selector "[role='tablist']"
    assert_selector "[role='tab']", count: 2
    assert_selector "[role='tabpanel']", text: "Overview content"
    assert_selector "button[role='tab']", count: 2
  end

  test "renders navigation links instead of panels when mode is :links" do
    render_inline(UiTabsComponent.new(mode: :links)) do |tabs|
      tabs.with_tab(title: "Profile", href: "/settings/profile", active: true)
      tabs.with_tab(title: "Password", href: "/settings/password", active: false)
      tabs.with_tab(title: "Billing", href: "/settings/billing", active: false)
    end

    # Real anchors, not buttons, carrying the caller-computed active state.
    assert_selector "a[href='/settings/profile'][aria-current='page']", text: "Profile"
    assert_selector "a[href='/settings/password']", text: "Password"
    assert_selector "a[href='/settings/billing']", text: "Billing"
    assert_no_selector "a[href='/settings/password'][aria-current]"
    assert_no_selector "a[href='/settings/billing'][aria-current]"
    assert_selector "[aria-current='page']", count: 1
    assert_no_selector "button"

    # No JS-driven panel machinery, tab semantics, or click-prevention.
    assert_no_selector "[data-controller='ui-tabs']"
    assert_no_selector "[role='tablist']"
    assert_no_selector "[role='tab']"
    assert_no_selector "[role='tabpanel']"
    assert_no_selector ".opacity-0"
    assert_no_match(/ui-tabs#change:prevent/, rendered_content)
    assert_no_match(/grid-template-columns/, rendered_content)

    # Natural-width items in a horizontal, overflow-scrollable row.
    assert_selector ".overflow-x-auto"
  end
end
