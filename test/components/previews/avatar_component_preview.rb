class AvatarComponentPreview < ViewComponent::Preview
  def default
    render AvatarComponent.new(alt: "Avery Stone")
  end

  def with_image
    render AvatarComponent.new(src: "/icon.svg", alt: "Avery Stone", size: :lg, status: :online)
  end

  def group
    group = AvatarComponent::GroupComponent.new(label: "Project members", remaining_count: 2)
    group.with_avatar(alt: "Avery Stone")
    group.with_avatar(alt: "Jordan Lee", fallback: "JL")
    render group
  end

  def animated_group
    group = AvatarComponent::GroupComponent.new(label: "Project members", animated: true)
    group.with_avatar(alt: "Avery Stone")
    group.with_avatar(alt: "Jordan Lee")
    render group
  end
end
