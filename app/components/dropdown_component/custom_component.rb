# frozen_string_literal: true

class DropdownComponent
  class CustomComponent < ViewComponent::Base
    # @param classes [String] Additional CSS classes for the wrapper
    # @param unstyled [Boolean] Render content without wrapper when true
    def initialize(classes: nil, unstyled: false)
      super()
      @classes = classes
      @unstyled = unstyled
    end

    def wrapper_classes
      return nil if @unstyled

      base = "px-2 py-1.5"
      [base, @classes].compact.reject(&:empty?).join(" ")
    end
  end
end
