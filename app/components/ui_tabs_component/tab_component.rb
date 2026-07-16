# frozen_string_literal: true

class UiTabsComponent
  class TabComponent < ViewComponent::Base
    attr_reader :title, :id, :icon, :meta, :disabled

    # @param title [String] Tab button text
    # @param id [String] Optional unique ID for the tab (used for URL anchors)
    # @param icon [String] Optional SVG icon HTML to display before title
    # @param meta [String] Optional meta text/number to display after title
    # @param badge [String] Legacy alias for meta
    # @param disabled [Boolean] Whether the tab is disabled
    # @param variant [Symbol] Style variant inherited from parent
    # @param classes [String] Additional CSS classes
    def initialize(title:, id: nil, icon: nil, meta: nil, badge: nil, disabled: false, variant: :pills, classes: nil)
      super()
      @title = title
      @id = id
      @icon = icon
      @meta = meta.presence || badge
      @disabled = disabled
      @variant = variant.to_sym
      @classes = classes
    rescue NoMethodError
      @variant = :pills
    end

    def unique_id
      @id || @unique_id ||= "tab-#{SecureRandom.hex(4)}"
    end

    def tab_classes
      shape = (@variant == :underline) ? "rounded-none" : "rounded-lg"
      low_contrast_border = (@variant == :low_contrast) ? "border border-transparent" : ""
      base = "#{shape} #{low_contrast_border} whitespace-nowrap text-xs font-medium transition flex gap-x-2 items-center justify-center py-2.5 px-3 w-full text-center"
      focus = "focus-visible:outline-offset-2 focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200"
      color = "text-current hover:text-current dark:text-current dark:hover:text-current"
      disabled_styles = @disabled ? "opacity-50 cursor-not-allowed" : ""

      [base, focus, color, disabled_styles, @classes].compact.reject(&:empty?).join(" ")
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
