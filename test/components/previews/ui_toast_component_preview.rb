class UiToastComponentPreview < ViewComponent::Preview
  def default
    render_with_template
  end

  def bottom_right
    render UiToastComponent.new(position: "bottom-right", layout: "expanded", limit: 4)
  end
end
