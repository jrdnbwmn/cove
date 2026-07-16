require "test_helper"
require "view_component/test_case"

class PaginationComponentTest < ViewComponent::TestCase
  test "renders accessible numbered pagination" do
    pagy = Pagy::Offset.new(
      count: 30,
      page: 2,
      limit: 10,
      request: Pagy::Request.new(request: {base_url: "http://test.host", path: "/projects", params: {}, cookie: nil})
    )

    render_inline(PaginationComponent.new(pagy: pagy, request_path: "/projects"))

    assert_selector "nav[aria-label='Pagination']"
    assert_selector "[aria-current='page']", text: "2"
  end

  test "renders the compact preview" do
    render_preview(:compact)

    assert_text "Page 2 of 3"
  end
end
