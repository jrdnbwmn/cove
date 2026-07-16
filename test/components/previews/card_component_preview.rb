class CardComponentPreview < ViewComponent::Preview
  def default
    render card_with_content
  end

  def elevated
    render card_with_content(variant: :elevated, shadow: :lg)
  end

  def well
    render card_with_content(variant: :well)
  end

  def with_sections
    card = CardComponent.new(divide: true)
    card.with_header { "Project summary" }
    card.with_body { "Three tasks are ready." }
    card.with_footer { "View project" }
    render card
  end

  def clickable
    render card_with_content(clickable: true, hoverable: true)
  end

  private

  def card_with_content(**options)
    CardComponent.new(**options).with_content("Card content")
  end
end
