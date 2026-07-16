# frozen_string_literal: true

class DropdownComponent
  class DividerComponent < ViewComponent::Base
    def call
      tag.div(class: "my-1 border-t border-neutral-100 dark:border-neutral-700")
    end
  end
end
