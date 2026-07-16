# frozen_string_literal: true

class UiTabsComponent
  class PanelComponent < ViewComponent::Base
    attr_reader :custom_classes

    # @param classes [String] Additional CSS classes
    def initialize(classes: nil)
      super()
      @custom_classes = classes
    end
  end
end
