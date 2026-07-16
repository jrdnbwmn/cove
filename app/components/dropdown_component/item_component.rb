# frozen_string_literal: true

class DropdownComponent
  class ItemComponent < ViewComponent::Base
    # @param text [String] The menu item text
    # @param href [String] Link URL (for link items)
    # @param tag [Symbol] Element tag: :a (default) or :button
    # @param icon [String] SVG icon HTML string (optional)
    # @param shortcut [String] Keyboard shortcut text (optional, e.g., "⌘K")
    # @param badge [String] Badge text (optional)
    # @param disabled [Boolean] Whether the item is disabled
    # @param destructive [Boolean] Whether the item has destructive styling (red text)
    # @param classes [String] Additional CSS classes
    def initialize(
      text:,
      href: "#",
      tag: :a,
      icon: nil,
      shortcut: nil,
      badge: nil,
      disabled: false,
      destructive: false,
      classes: nil,
      **options
    )
      super()
      @text = text
      @href = href
      @tag = tag
      @icon = icon
      @shortcut = shortcut
      @badge = badge
      @disabled = disabled
      @destructive = destructive
      @classes = classes
      @options = options
    end

    def item_classes
      base = "flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm"

      text_color = if @destructive
        "text-red-600 dark:text-red-400"
      else
        "text-neutral-700 dark:text-neutral-100"
      end

      state = if @disabled
        "cursor-not-allowed opacity-50"
      else
        "focus:bg-neutral-100 focus:outline-hidden dark:focus:bg-neutral-700/50"
      end

      [base, text_color, state, @classes].compact.reject(&:empty?).join(" ")
    end

    def item_attributes
      attrs = {
        class: item_classes,
        role: "menuitem",
        tabindex: "-1"
      }

      if @tag == :a
        attrs[:href] = @disabled ? nil : @href
      else
        attrs[:type] = "button"
        attrs[:disabled] = true if @disabled
      end

      attrs[:data] = {ui_menu_target: "item"}

      # Merge any additional options
      @options.each do |key, value|
        if key.to_s.start_with?("data_")
          attrs[:data] ||= {}
          data_key = key.to_s.sub("data_", "").tr("_", "-")
          attrs[:data][data_key] = value
        else
          attrs[key] = value
        end
      end

      attrs
    end

    attr_reader :text, :icon, :shortcut, :badge, :tag, :disabled
  end
end
