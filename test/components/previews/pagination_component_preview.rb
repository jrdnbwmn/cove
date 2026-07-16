class PaginationComponentPreview < ViewComponent::Preview
  def default
    render pagination_component
  end

  def compact
    render pagination_component(variant: :compact)
  end

  def minimal
    render pagination_component(variant: :minimal, show_info: false)
  end

  private

  def pagination_component(**options)
    request = Pagy::Request.new(request: {base_url: "http://test.host", path: "/projects", params: {}, cookie: nil})
    pagy = Pagy::Offset.new(count: 30, page: 2, limit: 10, request: request)
    PaginationComponent.new(pagy: pagy, request_path: "/projects", **options)
  end
end
