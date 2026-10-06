require "test_helper"
require "view_component/test_case"

class SegmentedControlComponentTest < ViewComponent::TestCase
  test "renders each option as a link to its href" do
    render_inline(SegmentedControlComponent.new(label: "Filter students")) do |control|
      control.with_option(text: "Active", href: "/students", selected: true)
      control.with_option(text: "Archived", href: "/students?archived=1")
    end

    assert_selector "a[href='/students']", text: "Active"
    assert_selector "a[href='/students?archived=1']", text: "Archived"
    assert_no_selector "button"
  end

  test "marks only the selected option as current" do
    render_inline(SegmentedControlComponent.new(label: "Filter students")) do |control|
      control.with_option(text: "Active", href: "/students", selected: true)
      control.with_option(text: "Archived", href: "/students?archived=1")
    end

    assert_selector "a[aria-current='true']", count: 1
    assert_selector "a[href='/students'][aria-current='true']", text: "Active"
    assert_no_selector "a[href='/students?archived=1'][aria-current]"
  end

  test "shows each option's count after its text when given" do
    render_inline(SegmentedControlComponent.new(label: "Filter students")) do |control|
      control.with_option(text: "Active", href: "/students", selected: true, count: 3)
      control.with_option(text: "Archived", href: "/students?archived=1", count: 0)
      control.with_option(text: "All", href: "/students?all=1")
    end

    assert_selector "a[href='/students'] span:first-child", text: "Active"
    assert_selector "a[href='/students'] span:last-child", text: "3"
    assert_selector "a[href='/students?archived=1'] span:last-child", text: "0"
    assert_selector "a[href='/students?all=1'] span", count: 1
  end

  test "labels the navigation group for screen readers" do
    render_inline(SegmentedControlComponent.new(label: "Filter students")) do |control|
      control.with_option(text: "Active", href: "/students", selected: true)
    end

    assert_selector "nav[aria-label='Filter students']"
  end

  test "renders the default preview" do
    render_preview(:default)

    assert_selector "nav a[aria-current='true']", text: "Active"
  end
end
