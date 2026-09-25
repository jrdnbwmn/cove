# frozen_string_literal: true

class SidebarComponent
  class ItemComponent < ViewComponent::Base
    # @param label [String] The display text for the nav item
    # @param href [String] The link URL
    # @param icon [String] SVG icon HTML (optional)
    # @param shortcut [String] Keyboard shortcut display (e.g., "⌘1")
    # @param active [Boolean] Whether this item is currently active
    # @param disabled [Boolean] Whether this item is disabled
    # @param badge [String] Optional badge text (e.g., count)
    # @param classes [String] Additional CSS classes
    def initialize(label:, href: "#", icon: nil, shortcut: nil, active: false, disabled: false, badge: nil, classes: nil)
      super()
      @label = label
      @href = href
      @icon = icon
      @shortcut = shortcut
      @active = active
      @disabled = disabled
      @badge = badge
      @classes = classes
    end

    def item_classes
      base = "group w-full flex items-center justify-between gap-2 rounded-md px-2 py-1.5 text-left text-base"
      state_classes = if @disabled
        "text-neutral-400 cursor-not-allowed opacity-50 dark:text-neutral-500"
      elsif @active
        "bg-muted text-foreground"
      else
        "text-foreground hover:bg-muted focus-visible:bg-muted focus:outline-hidden disabled:cursor-not-allowed disabled:opacity-50"
      end

      [base, state_classes, @classes].compact.reject(&:empty?).join(" ")
    end

    def collapsed_item_classes
      # AIDEV-NOTE: min-h-9 (36px) matches item_classes' rendered height (24px text-base
      # line-height + py-1.5). box-sizing is border-box here, so min-height is the total
      # box height, not just content — without it the icon alone (16-18px) plus py-1.5
      # renders a few px short of item_classes' text-driven height.
      # pl-2 (not justify-center) matches item_classes' own px-2 inset, so the icon's left
      # edge lines up with the expanded item's icon regardless of icon size.
      base = "flex min-h-9 w-8.5 items-center justify-start pl-2 rounded-lg py-1.5"
      state_classes = if @disabled
        "text-neutral-400 cursor-not-allowed opacity-50 dark:text-neutral-500"
      elsif @active
        "bg-muted text-foreground"
      else
        "text-foreground hover:bg-muted focus:outline-none focus-visible:bg-muted disabled:opacity-50"
      end

      [base, state_classes].join(" ")
    end

    def render?
      @label.present?
    end

    def icon?
      @icon.present?
    end

    def shortcut?
      @shortcut.present?
    end

    def badge?
      @badge.present?
    end

    attr_reader :label, :href, :icon, :shortcut, :active, :disabled, :badge
  end
end
