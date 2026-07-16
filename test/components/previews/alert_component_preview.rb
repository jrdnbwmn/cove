class AlertComponentPreview < ViewComponent::Preview
  def default
    render AlertComponent.new(title: "Success! Your changes have been saved", description: "All updates have been applied successfully.", variant: :success)
  end

  def error
    render AlertComponent.new(title: "Something went wrong", description: "We couldn't process your request. Please try again.", variant: :error)
  end

  def warning
    render AlertComponent.new(title: "Your plan is expiring soon", variant: :warning)
  end

  def info
    render AlertComponent.new(title: "New features are available", variant: :info)
  end

  def neutral
    render AlertComponent.new(title: "No changes to save", variant: :neutral, show_icon: false)
  end
end
