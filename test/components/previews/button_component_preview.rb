class ButtonComponentPreview < ViewComponent::Preview
  def default
    render ButtonComponent.new(text: "Primary Button")
  end

  def secondary
    render ButtonComponent.new(text: "Secondary Button", variant: :secondary)
  end

  def outline
    render ButtonComponent.new(text: "Outline Button", variant: :outline)
  end

  def ghost
    render ButtonComponent.new(text: "Ghost Button", variant: :ghost)
  end

  def destructive
    render ButtonComponent.new(text: "Delete", variant: :destructive)
  end

  def loading
    render ButtonComponent.new(text: "Saving", loading: true)
  end
end
