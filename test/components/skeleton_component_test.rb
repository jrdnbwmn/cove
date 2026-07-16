require "test_helper"
require "view_component/test_case"

class SkeletonComponentTest < ViewComponent::TestCase
  test "renders a single skeleton by default" do
    render_inline(SkeletonComponent.new)

    assert_selector "div.animate-pulse", count: 1
  end

  test "renders multiple skeletons when count is given" do
    render_inline(SkeletonComponent.new(count: 3))

    assert_selector "div.animate-pulse", count: 3
  end
end
