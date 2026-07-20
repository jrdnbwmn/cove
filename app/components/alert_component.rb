# frozen_string_literal: true

# AIDEV-NOTE: Rails Blocks generated Alert::Component; keep this app's catalog flat.
class AlertComponent < ViewComponent::Base
  VARIANTS = %i[success error warning info neutral].freeze

  # @param title [String] The alert title/heading
  # @param description [String] Optional description text (can include HTML)
  # @param variant [Symbol] Alert type: :success, :error, :warning, :info, :neutral
  # @param show_icon [Boolean] Whether to show the icon
  # @param custom_icon [String] Optional custom icon HTML/SVG (overrides variant icon)
  # @param classes [String] Additional CSS classes for the wrapper
  def initialize(title:, description: nil, variant: :success, show_icon: true, custom_icon: nil, classes: nil)
    super()
    @title = title
    @description = description
    @variant = VARIANTS.include?(variant) ? variant : :success
    @show_icon = show_icon
    @custom_icon = custom_icon
    @classes = classes
  end

  def wrapper_classes
    base = "rounded-xl border p-4"
    [base, colors[:border], colors[:bg], @classes].compact.reject(&:empty?).join(" ")
  end

  def layout_classes
    @description.present? ? "grid grid-cols-[auto_1fr] gap-2 items-start" : "flex gap-2 items-center"
  end

  def colors
    @colors ||= case @variant
    when :success
      {
        border: "border-green-200 dark:border-green-800",
        bg: "bg-green-50 dark:bg-green-900/20",
        icon: "text-green-500 dark:text-green-400",
        title: "text-green-800 dark:text-green-200",
        text: "text-green-700 dark:text-green-300"
      }
    when :error
      {
        border: "border-red-200 dark:border-red-800",
        bg: "bg-red-50 dark:bg-red-900/20",
        icon: "text-red-500 dark:text-red-400",
        title: "text-red-800 dark:text-red-200",
        text: "text-red-700 dark:text-red-300"
      }
    when :warning
      {
        border: "border-amber-200 dark:border-amber-800",
        bg: "bg-amber-50 dark:bg-amber-900/20",
        icon: "text-amber-500 dark:text-amber-400",
        title: "text-amber-800 dark:text-amber-200",
        text: "text-amber-700 dark:text-amber-300"
      }
    when :info
      {
        border: "border-blue-200 dark:border-blue-800",
        bg: "bg-blue-50 dark:bg-blue-900/20",
        icon: "text-blue-500 dark:text-blue-400",
        title: "text-blue-800 dark:text-blue-200",
        text: "text-blue-700 dark:text-blue-300"
      }
    when :neutral
      {
        border: "border-neutral-200 dark:border-neutral-700",
        bg: "bg-neutral-50 dark:bg-neutral-800/50",
        icon: "text-neutral-500 dark:text-neutral-400",
        title: "text-neutral-800 dark:text-neutral-200",
        text: "text-neutral-600 dark:text-neutral-400"
      }
    else
      {
        border: "border-neutral-200 dark:border-neutral-700",
        bg: "bg-neutral-50 dark:bg-neutral-800",
        icon: "text-neutral-500 dark:text-neutral-400",
        title: "text-neutral-800 dark:text-neutral-200",
        text: "text-neutral-700 dark:text-neutral-300"
      }
    end
  end

  def icon_svg
    return @custom_icon.html_safe if @custom_icon.present?

    case @variant
    when :success then icon("circle-check", class: "size-[18px]")
    when :error then icon("circle-alert", class: "size-[18px]")
    when :warning then icon("triangle-alert", class: "size-[18px]")
    when :info, :neutral then icon("info", class: "size-[18px]")
    else ""
    end
  end
end
