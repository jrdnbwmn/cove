# frozen_string_literal: true

class UiTabsComponent < ViewComponent::Base
  # AIDEV-NOTE: Rails Blocks generated Tabs::Component; keep it separate from Jumpstart's TabsComponent.
  VARIANTS = %i[pills underline low_contrast].freeze
  LEGACY_VARIANTS = {
    bordered: :low_contrast
  }.freeze
  ORIENTATIONS = %i[horizontal vertical].freeze

  renders_many :tabs, lambda { |title:, id: nil, icon: nil, meta: nil, badge: nil, disabled: false, classes: nil|
    tab_meta = meta.presence || badge

    UiTabsComponent::TabComponent.new(
      title: title,
      id: id,
      icon: icon,
      meta: tab_meta,
      disabled: disabled,
      variant: @variant,
      classes: classes
    )
  }

  renders_many :panels, lambda { |classes: nil|
    UiTabsComponent::PanelComponent.new(
      classes: classes
    )
  }

  # @param variant [Symbol] Visual style: :pills, :underline, :low_contrast (:bordered is a legacy alias)
  # @param orientation [Symbol] Tab layout: :horizontal, :vertical
  # @param default_tab [Integer] Index of tab to show on load (0-based)
  # @param url_sync [Boolean] Update URL hash when tab changes
  # @param scroll_to_anchor [Boolean] Scroll page when URL hash changes
  # @param auto_switch [Boolean] Enable automatic tab switching
  # @param auto_switch_interval [Integer] Interval in ms for auto-switching (default: 5000)
  # @param pause_on_hover [Boolean] Pause auto-switch on hover (default: true)
  # @param show_progress_bar [Boolean] Show progress bar for auto-switch
  # @param scroll_active_tab_into_view [Boolean] Scroll active tab into view
  # @param lazy_load [Boolean] Lazy load tab panel content
  # @param arrow_focus_only [Boolean] Arrow keys only change focus without switching tabs
  # @param classes [String] Additional CSS classes for the wrapper
  # @param tab_list_classes [String] Additional CSS classes for the tab list
  # @param panel_classes [String] Additional CSS classes for all panels
  def initialize(
    variant: :pills,
    orientation: :horizontal,
    default_tab: 0,
    url_sync: false,
    scroll_to_anchor: false,
    auto_switch: false,
    auto_switch_interval: 5000,
    pause_on_hover: true,
    show_progress_bar: false,
    scroll_active_tab_into_view: false,
    lazy_load: false,
    arrow_focus_only: false,
    classes: nil,
    tab_list_classes: nil,
    panel_classes: nil
  )
    super()
    @variant = normalized_variant(variant)
    @orientation = ORIENTATIONS.include?(orientation) ? orientation : :horizontal
    @default_tab = default_tab
    @url_sync = url_sync
    @scroll_to_anchor = scroll_to_anchor
    @auto_switch = auto_switch
    @auto_switch_interval = auto_switch_interval
    @pause_on_hover = pause_on_hover
    @show_progress_bar = show_progress_bar
    @scroll_active_tab_into_view = scroll_active_tab_into_view
    @lazy_load = lazy_load
    @arrow_focus_only = arrow_focus_only
    @classes = classes
    @tab_list_classes = tab_list_classes
    @panel_classes = panel_classes
  end

  def wrapper_classes
    base = "w-full"
    orientation_class = (@orientation == :vertical) ? "flex gap-6 flex-col sm:flex-row" : ""
    [base, orientation_class, @classes].compact.reject(&:empty?).join(" ")
  end

  def tab_list_wrapper_classes
    base = "opacity-0 transition-opacity duration-200"
    horizontal_gap = (@variant == :low_contrast) ? "gap-1" : "gap-2"

    orientation_classes = if @orientation == :vertical
      "flex flex-col gap-2 sm:w-48 space-y-1"
    else
      "relative inline-grid #{horizontal_gap} items-center justify-center w-full"
    end

    variant_classes = case @variant
    when :underline
      "border-b border-neutral-200 dark:border-neutral-700"
    when :low_contrast
      "p-1 bg-neutral-100/90 border border-neutral-200/80 rounded-xl dark:bg-neutral-800 dark:border-neutral-700"
    else # :pills
      "p-1 bg-neutral-100 border border-neutral-200 rounded-xl select-none dark:bg-neutral-800 dark:border-neutral-700"
    end

    [base, orientation_classes, variant_classes, @tab_list_classes].compact.reject(&:empty?).join(" ")
  end

  def tab_list_grid_cols
    return nil if @orientation == :vertical

    "grid-cols-1 sm:[grid-template-columns:repeat(var(--tabs-columns),minmax(0,1fr))]"
  end

  def tab_list_style
    return nil if @orientation == :vertical

    "--tabs-columns: #{[tabs.size, 1].max};"
  end

  def aria_orientation
    (@orientation == :vertical) ? "vertical" : "horizontal"
  end

  def controller_data
    data = {
      controller: "ui-tabs",
      ui_tabs_index_value: resolved_default_tab_index,
      ui_tabs_active_tab_class: active_tab_classes,
      ui_tabs_inactive_tab_class: inactive_tab_classes
    }

    data[:ui_tabs_update_anchor_value] = true if @url_sync
    data[:ui_tabs_scroll_to_anchor_value] = true if @scroll_to_anchor
    data[:ui_tabs_auto_switch_value] = true if @auto_switch
    data[:ui_tabs_auto_switch_interval_value] = @auto_switch_interval if @auto_switch && @auto_switch_interval != 5000
    data[:ui_tabs_pause_on_hover_value] = @pause_on_hover if @auto_switch
    data[:ui_tabs_show_progress_bar_value] = true if @show_progress_bar
    data[:ui_tabs_scroll_active_tab_into_view_value] = true if @scroll_active_tab_into_view
    data[:ui_tabs_lazy_load_value] = true if @lazy_load
    data[:ui_tabs_arrow_focus_only_value] = true if @arrow_focus_only

    {data: data}
  end

  def active_tab_classes
    case @variant
    when :underline
      "border-b-2 border-neutral-900 dark:border-white text-neutral-900 dark:text-white"
    when :low_contrast
      "bg-white text-neutral-900 border-neutral-200 shadow-xs dark:bg-neutral-700 dark:border-neutral-600 dark:text-neutral-100 dark:shadow-sm"
    else # :pills
      "bg-neutral-900 text-white shadow-xs dark:bg-white dark:text-neutral-900 dark:shadow-sm hover:ring-neutral-800 dark:hover:bg-neutral-50 dark:hover:ring-white hover:text-white dark:hover:text-neutral-900"
    end
  end

  def inactive_tab_classes
    case @variant
    when :underline
      "border-b-2 border-transparent text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-200"
    when :low_contrast
      "border-transparent text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-200 hover:bg-neutral-200/50 dark:hover:bg-neutral-700/60"
    else # :pills
      "hover:bg-white/75 ring-1 ring-transparent hover:ring-white dark:hover:bg-neutral-700 dark:hover:ring-neutral-600 text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-200"
    end
  end

  def vertical?
    @orientation == :vertical
  end

  def show_progress_bar?
    @auto_switch && @show_progress_bar
  end

  def default_panel_classes
    @panel_classes || "py-6 px-4"
  end

  def panel_wrapper_classes(panel, index)
    classes = [default_panel_classes, panel.custom_classes]
    classes << "hidden" if index.positive?
    classes.compact.reject(&:empty?).join(" ")
  end

  private

  def resolved_default_tab_index
    return 0 if tabs.empty?

    index = @default_tab.to_i
    index = index.clamp(0, tabs.size - 1)
    return index unless tabs[index]&.disabled

    1.upto(tabs.size) do |step|
      candidate = (index + step) % tabs.size
      return candidate unless tabs[candidate]&.disabled
    end

    index
  end

  def normalized_variant(variant)
    candidate = variant.to_sym
    candidate = LEGACY_VARIANTS.fetch(candidate, candidate)
    VARIANTS.include?(candidate) ? candidate : :pills
  rescue NoMethodError
    :pills
  end
end
