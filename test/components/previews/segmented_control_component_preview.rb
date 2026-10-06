class SegmentedControlComponentPreview < ViewComponent::Preview
  def default
    render SegmentedControlComponent.new(label: "Filter students") do |control|
      control.with_option(text: "Active", href: "#", selected: true)
      control.with_option(text: "Archived", href: "#")
    end
  end

  def with_counts
    render SegmentedControlComponent.new(label: "Filter students") do |control|
      control.with_option(text: "Active", href: "#", selected: true, count: 4)
      control.with_option(text: "Archived", href: "#", count: 2)
    end
  end

  def archived_selected
    render SegmentedControlComponent.new(label: "Filter students") do |control|
      control.with_option(text: "Active", href: "#", count: 0)
      control.with_option(text: "Archived", href: "#", selected: true, count: 2)
    end
  end
end
