# frozen_string_literal: true

class DropdownComponent
  class LabelComponent < ViewComponent::Base
    # @param text [String] The label text
    # @param classes [String] Additional CSS classes
    def initialize(text:, classes: nil)
      super()
      @text = text
      @classes = classes
    end

    def label_classes
      base = "px-2 py-1.5 text-xs font-semibold text-neutral-500 dark:text-neutral-400 uppercase tracking-wider"
      [base, @classes].compact.reject(&:empty?).join(" ")
    end

    attr_reader :text
  end
end
