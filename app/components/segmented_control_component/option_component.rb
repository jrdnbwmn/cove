# frozen_string_literal: true

class SegmentedControlComponent
  class OptionComponent < ViewComponent::Base
    attr_reader :text, :href, :count

    # @param text [String] Option label
    # @param href [String] Destination URL
    # @param selected [Boolean] Whether this option is the current view
    # @param count [Integer] Optional count shown after the text (0 is shown)
    def initialize(text:, href:, selected: false, count: nil)
      super()
      @text = text
      @href = href
      @selected = selected
      @count = count
    end

    def selected?
      @selected
    end

    def link_classes
      base = "inline-flex items-center gap-1.5 whitespace-nowrap rounded-md px-3 text-sm font-medium transition " \
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
      state = selected? ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"
      "#{base} #{state}"
    end

    def count_classes
      "text-xs tabular-nums #{selected? ? "text-primary-foreground" : "text-muted-foreground"}"
    end
  end
end
