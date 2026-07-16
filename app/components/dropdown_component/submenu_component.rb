# frozen_string_literal: true

class DropdownComponent
  class SubmenuComponent < ViewComponent::Base
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

    # @param text [String] The submenu trigger text
    # @param icon [String] SVG icon HTML string (optional)
    # @param placement [String] Submenu position (default: "right-start")
    # @param hover [Boolean] Whether to open on hover (default: false for nested)
    # @param auto_close [Boolean] Whether to close menu on item click (default: false for submenus)
    # @param classes [String] Additional CSS classes
    def initialize(text:, icon: nil, placement: "right-start", hover: false, auto_close: false, classes: nil)
      super()
      @text = text
      @icon = icon
      @placement = placement
      @hover = hover
      @auto_close = auto_close
      @classes = classes
    end

    def controller_data
      data = {
        controller: "ui-dropdown-popover",
        ui_dropdown_popover_nested_value: true
      }
      data[:ui_dropdown_popover_hover_value] = true if @hover
      data[:ui_dropdown_popover_auto_close_value] = false unless @auto_close
      {data: data}
    end

    def trigger_classes
      base = "flex w-full items-center justify-between rounded-md px-2 py-1.5 text-left text-sm text-neutral-700 data-[highlighted]:bg-neutral-100 focus:outline-hidden data-[state=open]:!bg-neutral-400/20 dark:text-neutral-100 dark:data-[highlighted]:bg-neutral-700/50"
      [base, @classes].compact.reject(&:empty?).join(" ")
    end

    def menu_classes
      "absolute top-0 left-full z-20 ml-1 w-48 rounded-md border border-neutral-200 bg-white text-neutral-900 opacity-0 shadow-md transition-opacity duration-150 ease-out outline-hidden dark:border-neutral-700/50 dark:bg-neutral-800 dark:text-neutral-100 [&[open]]:scale-100 [&[open]]:opacity-100 scale-100 opacity-100"
    end

    attr_reader :text, :icon

    def render_chevron_icon
      %(<svg xmlns="http://www.w3.org/2000/svg" class="transform-gpu size-3" width="12" height="12" viewBox="0 0 12 12"><g fill="currentColor"><path d="m4.25,11c-.192,0-.384-.073-.53-.22-.293-.293-.293-.768,0-1.061l3.72-3.72-3.72-3.72c-.293-.293-.293-.768,0-1.061s.768-.293,1.061,0l4.25,4.25c.293.293.293.768,0,1.061l-4.25,4.25c-.146.146-.338.22-.53.22Z" stroke-width="0"></path></g></svg>).html_safe
    end
  end
end
