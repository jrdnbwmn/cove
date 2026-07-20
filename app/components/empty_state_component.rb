# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  SIZES = %i[sm md lg].freeze
  HEADING_LEVELS = (1..6)

  renders_one :icon
  renders_one :primary_action
  renders_one :secondary_action

  # @param title [String] The heading text (required)
  # @param description [String] Optional supporting text below the title
  # @param size [Symbol] Scales icon, text, and padding: :sm, :md, :lg
  # @param bordered [Boolean] Wrap content in a dashed bordered well
  # @param heading_level [Integer] 1..6, sets the title's heading tag
  # @param classes [String] Additional CSS classes for the wrapper
  def initialize(title:, description: nil, size: :md, bordered: false, heading_level: 2, classes: nil)
    super()
    @title = title
    @description = description
    @size = SIZES.include?(size) ? size : :md
    @bordered = bordered
    @heading_level = HEADING_LEVELS.include?(heading_level) ? heading_level : 2
    @classes = classes
  end

  def wrapper_classes
    [
      "flex flex-col items-center text-center max-w-sm mx-auto",
      padding_classes,
      bordered_classes,
      @classes
    ].compact.reject(&:empty?).join(" ")
  end

  def icon_wrapper_classes
    [
      "flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-neutral-100 text-neutral-400 dark:bg-neutral-800",
      icon_size_classes
    ].join(" ")
  end

  def title_classes
    ["text-neutral-900 dark:text-neutral-100 font-semibold", title_size_classes].join(" ")
  end

  def description_classes
    ["mt-2 text-neutral-500 dark:text-neutral-400", description_size_classes].join(" ")
  end

  def action_row_classes
    ["flex justify-center gap-3", action_margin_classes].join(" ")
  end

  def heading_tag
    "h#{@heading_level}"
  end

  private

  def padding_classes
    case @size
    when :sm then "py-8"
    when :lg then "py-16"
    else "py-12" # :md
    end
  end

  def bordered_classes
    return "" unless @bordered

    "border border-dashed border-black/10 dark:border-white/10 rounded-xl px-6"
  end

  def icon_size_classes
    case @size
    when :sm then "w-8 h-8 mb-3"
    when :lg then "w-16 h-16 mb-5"
    else "w-12 h-12 mb-4" # :md
    end
  end

  def title_size_classes
    case @size
    when :sm then "text-base"
    when :lg then "text-xl"
    else "text-lg" # :md
    end
  end

  def description_size_classes
    case @size
    when :lg then "text-base"
    else "text-sm" # :sm, :md
    end
  end

  def action_margin_classes
    case @size
    when :sm then "mt-4"
    when :lg then "mt-8"
    else "mt-6" # :md
    end
  end
end
