class LoadingIndicatorComponentPreview < ViewComponent::Preview
  def default
    render LoadingIndicatorComponent.new
  end

  def stepped
    render LoadingIndicatorComponent.new(stepped: true)
  end

  def dots
    render LoadingIndicatorComponent.new(type: :dots)
  end

  def bars
    render LoadingIndicatorComponent.new(type: :bars)
  end

  def progress
    render LoadingIndicatorComponent.new(type: :progress, progress: 65)
  end

  def primary
    render LoadingIndicatorComponent.new(color: :primary, text: "Loading...")
  end
end
