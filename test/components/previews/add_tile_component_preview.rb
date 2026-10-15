class AddTileComponentPreview < ViewComponent::Preview
  def default
    render AddTileComponent.new(text: "Add learner")
  end

  def with_cards
    render_with_template
  end
end
