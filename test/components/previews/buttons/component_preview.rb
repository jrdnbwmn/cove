class Buttons::ComponentPreview < ViewComponent::Preview
  def default
    render Buttons::Component.new(text: "Primary Button")
  end

  def secondary
    render Buttons::Component.new(text: "Secondary Button", variant: :secondary)
  end

  def outline
    render Buttons::Component.new(text: "Outline Button", variant: :outline)
  end

  def ghost
    render Buttons::Component.new(text: "Ghost Button", variant: :ghost)
  end

  def destructive
    render Buttons::Component.new(text: "Delete", variant: :destructive)
  end

  def loading
    render Buttons::Component.new(text: "Saving", loading: true)
  end
end
