# frozen_string_literal: true

class UiTabsComponent
  class TabComponent < ViewComponent::Base
    attr_reader :title, :id, :href, :active, :icon, :meta, :disabled

    # @param title [String] Tab button/link text
    # @param id [String] Optional unique ID for the tab (used for URL anchors, :panels mode only)
    # @param href [String] Destination URL (:links mode only)
    # @param active [Boolean] Whether this link is the current page (:links mode only)
    # @param icon [String] Optional SVG icon HTML to display before title
    # @param meta [String] Optional meta text/number to display after title
    # @param badge [String] Legacy alias for meta
    # @param disabled [Boolean] Whether the tab is disabled
    # @param variant [Symbol] Style variant inherited from parent
    # @param mode [Symbol] :panels or :links, inherited from parent
    # @param active_class [String] Classes applied when active (:links mode only), inherited from parent
    # @param inactive_class [String] Classes applied when inactive (:links mode only), inherited from parent
    # @param classes [String] Additional CSS classes
    def initialize(title:, id: nil, href: nil, active: false, icon: nil, meta: nil, badge: nil, disabled: false, variant: :pills, mode: :panels, active_class: nil, inactive_class: nil, classes: nil)
      super()
      @title = title
      @id = id
      @href = href
      @active = active
      @icon = icon
      @meta = meta.presence || badge
      @disabled = disabled
      @variant = variant.to_sym
      @mode = mode
      @active_class = active_class
      @inactive_class = inactive_class
      @classes = classes
    rescue NoMethodError
      @variant = :pills
    end

    def links_mode?
      @mode == :links
    end

    def unique_id
      @id || @unique_id ||= "tab-#{SecureRandom.hex(4)}"
    end

    def tab_classes
      shape = (@variant == :underline) ? "rounded-none" : "rounded-lg"
      low_contrast_border = (@variant == :low_contrast) ? "border border-transparent" : ""
      width_class = links_mode? ? "" : "w-full "
      base = "#{shape} #{low_contrast_border} whitespace-nowrap text-sm font-medium transition flex gap-x-2 items-center justify-center py-2.5 px-3 #{width_class}text-center"
      focus = "focus-visible:outline-offset-2 focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200"
      color = "text-current hover:text-current dark:text-current dark:hover:text-current"
      disabled_styles = @disabled ? "opacity-50 cursor-not-allowed" : ""

      [base, focus, color, disabled_styles, links_state_classes, @classes].compact.reject(&:empty?).join(" ")
    end

    def links_state_classes
      return nil unless links_mode?

      active ? @active_class : @inactive_class
    end

    def meta_classes
      "inline-flex items-center gap-0.5 rounded-full bg-neutral-50 px-1.5 py-0.5 text-[11px] font-medium " \
        "text-neutral-700 outline outline-neutral-500/20 dark:bg-neutral-400/10 dark:text-neutral-400 " \
        "dark:outline-neutral-400/25"
    end

    def render?
      true
    end
  end
end
