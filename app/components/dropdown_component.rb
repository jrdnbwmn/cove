# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  # AIDEV-NOTE: Rails Blocks' generated subcomponents live under DropdownComponent to keep the public API flat.
  PLACEMENTS = %w[
    bottom bottom-start bottom-end
    top top-start top-end
    left left-start left-end
    right right-start right-end
  ].freeze
  TRIGGER_VARIANTS = %i[button icon text].freeze
  ICON_TRIGGER_CLASSES = "flex items-center justify-center gap-1.5 rounded-lg border border-black/10 bg-white/90 p-2.5 text-xs font-medium whitespace-nowrap text-neutral-800 shadow-xs transition-all duration-100 ease-in-out select-none hover:bg-neutral-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-600 disabled:cursor-not-allowed disabled:opacity-50 data-[state=open]:bg-neutral-50 dark:border-white/10 dark:bg-neutral-700/50 dark:text-neutral-50 dark:hover:bg-neutral-700/75 dark:focus-visible:outline-neutral-200 dark:data-[state=open]:bg-neutral-700/75"
  BUTTON_TRIGGER_CLASSES = "flex items-center justify-center gap-1.5 rounded-lg border border-black/10 bg-white/90 px-3.5 py-2 text-sm font-medium whitespace-nowrap text-neutral-800 shadow-xs transition-all duration-100 ease-in-out select-none hover:bg-neutral-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-600 disabled:cursor-not-allowed disabled:opacity-50 data-[state=open]:bg-neutral-50 dark:border-white/10 dark:bg-neutral-700/50 dark:text-neutral-50 dark:hover:bg-neutral-700/75 dark:focus-visible:outline-neutral-200 dark:data-[state=open]:bg-neutral-700/75"

  renders_one :trigger
  renders_many :items, types: {
    link: {
      renders: lambda { |text:, href: "#", icon: nil, shortcut: nil, badge: nil, disabled: false, destructive: false, classes: nil|
        DropdownComponent::ItemComponent.new(
          text: text,
          href: href,
          icon: icon,
          shortcut: shortcut,
          badge: badge,
          disabled: disabled,
          destructive: destructive,
          classes: classes
        )
      }
    },
    button: {
      renders: lambda { |text:, icon: nil, shortcut: nil, badge: nil, disabled: false, destructive: false, classes: nil, **options|
        DropdownComponent::ItemComponent.new(
          text: text,
          tag: :button,
          icon: icon,
          shortcut: shortcut,
          badge: badge,
          disabled: disabled,
          destructive: destructive,
          classes: classes,
          **options
        )
      }
    },
    submenu: {
      renders: lambda { |text:, icon: nil, placement: "right-start", hover: false, **options|
        DropdownComponent::SubmenuComponent.new(
          text: text,
          icon: icon,
          placement: placement,
          hover: hover,
          **options
        )
      }
    },
    divider: {
      renders: ->(**_options) { DropdownComponent::DividerComponent.new },
      as: :divider
    },
    label: {
      renders: ->(text:, classes: nil) { DropdownComponent::LabelComponent.new(text: text, classes: classes) }
    },
    custom: {
      renders: ->(classes: nil, unstyled: false) { DropdownComponent::CustomComponent.new(classes: classes, unstyled: unstyled) }
    }
  }

  # Keep a consistent API with other item helpers in docs/examples.
  def with_item_divider(**options, &block)
    with_divider(**options, &block)
  end

  def with_item_divider_content(*args, **options, &block)
    with_divider_content(*args, **options, &block)
  end

  # @param placement [String] Menu position: "bottom", "bottom-start", "bottom-end", "top", "top-start", "top-end", "left", "right"
  # @param trigger_text [String] Text for the default trigger button
  # @param trigger_variant [Symbol] Trigger style: :button (default), :icon (icon-only), :text (text link)
  # @param trigger_icon [String] SVG icon for trigger (optional, shows chevron by default for button variant)
  # @param auto_close [Boolean] Whether to close menu on item click (default: true)
  # @param hover [Boolean] Whether to open on hover (default: false)
  # @param portal [Boolean] Whether to move top-level menus to body while open (default: true)
  # @param width [String] Menu width class (default: "w-48")
  # @param classes [String] Additional CSS classes for the wrapper
  # @param trigger_classes [String] Additional CSS classes for the trigger
  # @param menu_classes [String] Additional CSS classes for the menu
  # @param menu_role [String] ARIA role on menu content container (default: "menu")
  # @param trigger_aria_haspopup [String] aria-haspopup value for default trigger (default: "menu")
  # @param trigger_aria_controls [String, nil] Optional aria-controls value for default trigger
  # @param menu_id [String, nil] Optional id attribute for menu dialog
  # @param flip_class [String, nil] Optional data-ui-dropdown-popover-flip-class value
  def initialize(
    placement: "bottom-start",
    trigger_text: "Open Menu",
    trigger_variant: :button,
    trigger_icon: nil,
    auto_close: true,
    hover: false,
    portal: true,
    width: "w-48",
    classes: nil,
    trigger_classes: nil,
    menu_classes: nil,
    menu_role: "menu",
    trigger_aria_haspopup: "menu",
    trigger_aria_controls: nil,
    menu_id: nil,
    flip_class: nil
  )
    super()
    @placement = PLACEMENTS.include?(placement.to_s) ? placement.to_s : "bottom-start"
    @trigger_text = trigger_text
    @trigger_variant = TRIGGER_VARIANTS.include?(trigger_variant) ? trigger_variant : :button
    @trigger_icon = trigger_icon
    @auto_close = auto_close
    @hover = hover
    @portal = portal
    @width = width
    @classes = classes
    @trigger_classes = trigger_classes
    @menu_classes = menu_classes
    @menu_role = menu_role
    @trigger_aria_haspopup = trigger_aria_haspopup
    @trigger_aria_controls = trigger_aria_controls
    @menu_id = menu_id
    @flip_class = flip_class
  end

  def controller_data
    data = {controller: "ui-dropdown-popover"}
    data[:ui_dropdown_popover_placement_value] = @placement unless @placement == "bottom-start"
    data[:ui_dropdown_popover_auto_close_value] = false unless @auto_close
    data[:ui_dropdown_popover_hover_value] = true if @hover
    data[:ui_dropdown_popover_portal_value] = false unless @portal
    data[:ui_dropdown_popover_flip_class] = @flip_class if @flip_class.present?
    {data: data}
  end

  def wrapper_classes
    base = "relative w-fit"
    [base, @classes].compact.reject(&:empty?).join(" ")
  end

  def default_trigger_classes
    base = case @trigger_variant
    when :icon
      ICON_TRIGGER_CLASSES
    when :text
      "flex items-center gap-1.5 text-sm font-medium text-neutral-700 hover:text-neutral-900 dark:text-neutral-300 dark:hover:text-neutral-100"
    else
      BUTTON_TRIGGER_CLASSES
    end
    [@trigger_classes, base].compact.reject(&:empty?).join(" ")
  end

  def menu_wrapper_classes
    base = "absolute z-10 rounded-lg border border-neutral-200 bg-white text-neutral-900 opacity-0 shadow-md transition-opacity duration-150 ease-out outline-hidden dark:border-neutral-700/50 dark:bg-neutral-800 dark:text-neutral-100"
    [@width, @menu_classes, base].compact.reject(&:empty?).join(" ")
  end

  attr_reader :trigger_text, :trigger_variant, :trigger_icon, :menu_role, :trigger_aria_haspopup, :trigger_aria_controls, :menu_id

  def render_default_trigger_icon
    if @trigger_variant == :icon
      render_kebab_icon
    else
      render_chevron_icon
    end
  end

  private

  def render_chevron_icon
    %(<svg xmlns="http://www.w3.org/2000/svg" class="size-2.5 transition-transform duration-200 [[data-state=open]_&]:rotate-180" width="12" height="12" viewBox="0 0 12 12"><g fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" stroke="currentColor"><polyline points="1.75 4.25 6 8.5 10.25 4.25"></polyline></g></svg>).html_safe
  end

  def render_kebab_icon
    %(<svg viewBox="0 0 16 16" class="size-3.5 sm:size-4" fill="currentColor"><path d="M8 2a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM8 6.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM9.5 12.5a1.5 1.5 0 1 0-3 0 1.5 1.5 0 0 0 3 0Z"></path></svg>).html_safe
  end
end
