class SkeletonComponentPreview < ViewComponent::Preview
  def default
    render SkeletonComponent.new
  end

  def circle
    render SkeletonComponent.new(variant: :circle)
  end

  def button
    render SkeletonComponent.new(variant: :button)
  end

  def multiple_lines
    render SkeletonComponent.new(count: 3)
  end
end
