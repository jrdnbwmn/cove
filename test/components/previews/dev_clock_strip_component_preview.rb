class DevClockStripComponentPreview < ViewComponent::Preview
  def default
    render DevClockStripComponent.new(date: Date.new(2026, 10, 14))
  end

  def no_override
    render DevClockStripComponent.new(date: nil)
  end
end
