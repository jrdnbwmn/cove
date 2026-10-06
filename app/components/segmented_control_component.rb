# frozen_string_literal: true

# AIDEV-NOTE: Built from scratch (COV-107): Rails Blocks has no segmented control, and its Tabs are
# for switching page views. This filters a list; each option is a plain link to its own URL.
class SegmentedControlComponent < ViewComponent::Base
  renders_many :options, lambda { |text:, href:, selected: false, count: nil|
    SegmentedControlComponent::OptionComponent.new(text: text, href: href, selected: selected, count: count)
  }

  # @param label [String] Accessible name for the group (e.g. "Filter students")
  def initialize(label:)
    super()
    @label = label
  end
end
