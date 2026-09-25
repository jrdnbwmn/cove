# frozen_string_literal: true

module Drawer
  class Component < ViewComponent::Base
    SNAP_POINT_PRESETS = {
      auto: ["auto"],
      small: ["180px"],
      medium: ["50%"],
      large: ["80%"],
      full: ["100%"],
      expandable: ["180px", "80%"]
    }.freeze

    renders_one :header
    renders_one :footer
    renders_one :trigger

    # @param snap_points [Array, Symbol] Snap points array or preset (:auto, :small, :medium, :large, :full, :expandable)
    # @param title [String] Optional title shown in the drawer header
    # @param show_handle [Boolean] Whether to show the drag handle (default: true)
    # @param dismissible [Boolean] Allow closing via drag, ESC, or backdrop click (default: true)
    # @param show_close_button [Boolean] Whether to show the close button (default: false)
    # @param lazy_load [Boolean] Lazy load content when drawer opens (default: false)
    # @param turbo_frame_src [String] URL for Turbo Frame lazy loading (optional)
    # @param close_threshold [Float] Percentage of drawer height to trigger close (default: 0.25)
    # @param scroll_lock_timeout [Integer] Milliseconds to block close-drag after scrolling content (default: 100)
    # @param respect_reduced_motion [Boolean] Respect user's reduced-motion preference (default: true)
    # @param fade_from_index [Integer] Start fading overlay from this snap index (-1 to disable)
    # @param classes [String] Additional CSS classes for the dialog element
    # @param trigger_text [String] Text for the trigger button (default: "Open Drawer")
    # @param trigger_classes [String] Additional classes for the trigger button
    # @param open [Boolean] Whether the drawer should be open by default (default: false)
    # @param max_width [String] Max width of the drawer (default: "max-w-2xl")
    #
    # Pass a `with_trigger` block for custom trigger markup (e.g. an icon-only
    # button) instead of the default `trigger_text` button. The custom markup
    # must include `data-action="drawer#show:prevent"` itself.
    def initialize(
      snap_points: :auto,
      title: nil,
      show_handle: true,
      dismissible: true,
      show_close_button: false,
      lazy_load: false,
      turbo_frame_src: nil,
      close_threshold: 0.25,
      scroll_lock_timeout: 100,
      respect_reduced_motion: true,
      fade_from_index: -1,
      classes: nil,
      trigger_text: "Open Drawer",
      trigger_classes: nil,
      open: false,
      max_width: "max-w-2xl"
    )
      super()
      @snap_points = resolve_snap_points(snap_points)
      @title = title
      @show_handle = show_handle
      @dismissible = dismissible
      @show_close_button = show_close_button
      @lazy_load = lazy_load
      @turbo_frame_src = turbo_frame_src
      @close_threshold = close_threshold
      @scroll_lock_timeout = scroll_lock_timeout
      @respect_reduced_motion = respect_reduced_motion
      @fade_from_index = fade_from_index
      @classes = classes
      @trigger_text = trigger_text
      @trigger_classes = trigger_classes
      @open = open
      @max_width = max_width
    end

    def controller_data
      data = {
        controller: "drawer",
        drawer_snap_points_value: @snap_points.to_json
      }
      data[:drawer_dismissible_value] = false unless @dismissible
      data[:drawer_lazy_load_value] = true if @lazy_load
      data[:drawer_turbo_frame_src_value] = @turbo_frame_src if @turbo_frame_src.present?
      data[:drawer_close_threshold_value] = @close_threshold if @dismissible && custom_close_threshold?
      data[:drawer_scroll_lock_timeout_value] = @scroll_lock_timeout if @dismissible && @scroll_lock_timeout != 100
      data[:drawer_respect_reduced_motion_value] = false unless @respect_reduced_motion
      data[:drawer_fade_from_index_value] = @fade_from_index if @dismissible && @fade_from_index != -1
      data[:drawer_open_value] = true if @open
      {data: data}
    end

    def dialog_classes
      base = "drawer w-full border-x border-t border-black/10 dark:border-white/10"
      [base, @max_width, @classes].compact.reject(&:empty?).join(" ")
    end

    def content_wrapper_classes
      base = if @dismissible
        "relative flex flex-col rounded-t-3xl bg-white dark:bg-neutral-800"
      else
        "rounded-t-xl bg-white dark:bg-neutral-800"
      end
      base = "relative #{base}" if @show_close_button && !@dismissible
      (@dismissible && scrollable_content?) ? "#{base} h-full" : base
    end

    def handle_classes
      "shrink-0 cursor-grab select-none active:cursor-grabbing group"
    end

    def handle_bar_classes
      "mx-auto my-4 h-1.5 w-10 rounded-full bg-neutral-200 group-hover:bg-neutral-300 group-active:bg-neutral-400 dark:bg-neutral-700 dark:group-hover:bg-neutral-600 dark:group-active:bg-neutral-500"
    end

    def trigger_button_classes
      base = "flex items-center justify-center gap-1.5 rounded-lg border border-neutral-400/30 bg-neutral-800 px-3.5 py-2 text-sm font-medium whitespace-nowrap text-white shadow-sm transition-all duration-100 ease-in-out select-none hover:bg-neutral-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-600 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-white dark:text-neutral-800 dark:hover:bg-neutral-100 dark:focus-visible:outline-neutral-200"
      [@trigger_classes, base].compact.reject(&:empty?).join(" ")
    end

    def close_button_classes
      "z-10 p-1.5 absolute right-4 top-4 rounded-full bg-neutral-500/10 opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-hidden hover:bg-neutral-500/15 active:bg-neutral-500/25 disabled:pointer-events-none"
    end

    def title_classes
      "text-xl font-semibold text-neutral-900 dark:text-white"
    end

    def header_classes
      "border-b border-neutral-200 px-6 pb-4 dark:border-neutral-700"
    end

    def footer_classes
      "shrink-0 flex gap-2 border-t border-neutral-200 p-4 dark:border-neutral-700"
    end

    def body_container_classes
      "min-h-0 flex flex-1 flex-col"
    end

    def body_classes
      if @dismissible
        "outline-none small-scrollbar min-h-0 flex-1 overflow-y-auto px-6 pt-4 pb-6"
      else
        "px-6 py-4"
      end
    end

    def scrollable_body?
      @dismissible
    end

    def render_handle?
      @dismissible && @show_handle
    end

    def render_close_icon
      tag.svg(
        xmlns: "http://www.w3.org/2000/svg",
        class: "size-4",
        width: "24",
        height: "24",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        "stroke-width": "2",
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      ) do
        safe_join([
          tag.line(x1: "18", x2: "6", y1: "6", y2: "18"),
          tag.line(x1: "6", x2: "18", y1: "6", y2: "18")
        ])
      end
    end

    attr_reader :title, :show_handle, :dismissible, :show_close_button, :lazy_load, :trigger_text

    private

    def resolve_snap_points(snap_points)
      case snap_points
      when Symbol
        SNAP_POINT_PRESETS[snap_points] || SNAP_POINT_PRESETS[:auto]
      when Array
        snap_points
      else
        SNAP_POINT_PRESETS[:auto]
      end
    end

    def scrollable_content?
      # Check if snap points suggest scrollable content (larger than auto)
      @snap_points.any? { |sp| sp.to_s.include?("%") && sp.to_s.gsub("%", "").to_i > 50 }
    end

    def custom_close_threshold?
      (@close_threshold - 0.25).abs > Float::EPSILON
    end
  end
end
