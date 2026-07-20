# frozen_string_literal: true

class NavbarComponent
  class ItemComponent < ViewComponent::Base
    ALIGNMENTS = %i[start center end].freeze

    attr_reader :label, :href, :dropdown, :content_id, :mobile_hidden

    # @param label [String] The navigation item label
    # @param href [String] URL for link items (ignored for dropdowns)
    # @param dropdown [Boolean] Whether this item triggers a dropdown
    # @param content_id [String] ID of the dropdown content panel (required if dropdown: true)
    # @param align [Symbol] Dropdown alignment: :start, :center, :end
    # @param mobile_hidden [Boolean] Whether to hide this item on mobile
    # @param classes [String] Additional CSS classes
    def initialize(label:, href: nil, dropdown: false, content_id: nil, align: :center, mobile_hidden: false, classes: nil)
      super()
      @label = label
      @href = href
      @dropdown = dropdown
      @content_id = content_id
      @align = ALIGNMENTS.include?(align) ? align : :center
      @mobile_hidden = mobile_hidden
      @classes = classes
    end

    def dropdown?
      @dropdown
    end

    def li_classes
      base = mobile_hidden ? "hidden sm:block" : ""
      [base, @classes].compact.reject(&:empty?).join(" ")
    end

    def link_classes
      "block rounded-md px-3 py-2 text-sm font-medium text-neutral-700 no-underline select-none " \
        "hover:bg-neutral-100 dark:text-neutral-300 dark:hover:bg-neutral-700 " \
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200"
    end

    def trigger_classes
      "group flex items-center gap-1 rounded-md px-3 py-2 text-sm font-medium text-neutral-700 select-none " \
        "hover:bg-neutral-100 dark:text-neutral-300 dark:hover:bg-neutral-700 " \
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200"
    end

    def trigger_actions
      "click->navbar#toggleMenu pointerenter->navbar#handlePointerEnter pointermove->navbar#handlePointerMove pointerleave->navbar#handlePointerLeave keydown->navbar#handleTriggerKeydown"
    end

    def align_value
      @align.to_s
    end

    def chevron_icon
      icon("chevron-down", class: "size-3 transition-transform duration-200 group-data-[state=open]:rotate-180")
    end
  end
end
