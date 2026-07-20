# frozen_string_literal: true

class UiModalComponent < ViewComponent::Base
  # AIDEV-NOTE: This keeps Rails Blocks' modal separate from Jumpstart's existing ModalComponent.
  SIZES = %i[sm md lg xl 2xl 3xl 4xl 5xl 6xl 7xl fullscreen].freeze

  renders_one :header
  renders_one :footer

  # @param size [Symbol] Modal width: :sm, :md, :lg, :xl, :"2xl", :"3xl", :"4xl", :"5xl", :"6xl", :"7xl", :fullscreen
  # @param title [String] Optional title shown in the modal header
  # @param show_close_button [Boolean] Whether to show the close button (default: true)
  # @param prevent_dismiss [Boolean] Prevent closing via ESC or backdrop click (default: false)
  # @param lazy_load [Boolean] Lazy load content when modal opens (default: false)
  # @param turbo_frame_src [String] URL for Turbo Frame lazy loading (optional)
  # @param auto_focus [Boolean] Auto-focus first focusable element on open (default: false)
  # @param classes [String] Additional CSS classes for the dialog element
  # @param trigger_text [String] Text for the trigger button (default: "Open Modal")
  # @param trigger_classes [String] Additional classes for the trigger button
  def initialize(
    size: :md,
    title: nil,
    show_close_button: true,
    prevent_dismiss: false,
    lazy_load: false,
    turbo_frame_src: nil,
    auto_focus: false,
    classes: nil,
    trigger_text: "Open Modal",
    trigger_classes: nil
  )
    super()
    @size = SIZES.include?(size) ? size : :md
    @title = title
    @show_close_button = show_close_button
    @prevent_dismiss = prevent_dismiss
    @lazy_load = lazy_load
    @turbo_frame_src = turbo_frame_src
    @auto_focus = auto_focus
    @classes = classes
    @trigger_text = trigger_text
    @trigger_classes = trigger_classes
  end

  def controller_data
    data = {controller: "ui-modal"}
    data[:ui_modal_prevent_dismiss_value] = true if @prevent_dismiss
    data[:ui_modal_lazy_load_value] = true if @lazy_load
    data[:ui_modal_turbo_frame_src_value] = @turbo_frame_src if @turbo_frame_src.present?
    data[:ui_modal_auto_focus_value] = true if @auto_focus
    {data: data}
  end

  def dialog_classes
    base = if @size == :fullscreen
      "modal bg-transparent w-full z-50 small-scrollbar focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200"
    else
      "modal bg-transparent rounded-xl w-full lg:rounded-2xl z-50 border border-black/10 dark:border-white/10 bg-white dark:bg-neutral-800 small-scrollbar focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200"
    end
    [base, size_classes, @classes].compact.reject(&:empty?).join(" ")
  end

  def size_classes
    case @size
    when :sm
      "max-w-sm"
    when :md
      "max-w-[100vw-2rem] sm:max-w-md"
    when :lg
      "max-w-[100vw-2rem] sm:max-w-lg"
    when :xl
      "max-w-[100vw-2rem] sm:max-w-xl"
    when :"2xl"
      "max-w-[100vw-2rem] sm:max-w-2xl"
    when :"3xl"
      "max-w-[100vw-2rem] sm:max-w-3xl"
    when :"4xl"
      "max-w-[100vw-2rem] sm:max-w-4xl"
    when :"5xl"
      "max-w-[100vw-2rem] sm:max-w-5xl"
    when :"6xl"
      "max-w-[100vw-2rem] sm:max-w-6xl"
    when :"7xl"
      "max-w-[100vw-2rem] sm:max-w-7xl"
    when :fullscreen
      "relative m-0 h-full w-full max-h-full max-w-full rounded-none lg:rounded-none"
    else
      "max-w-[100vw-2rem] sm:max-w-md"
    end
  end

  def content_wrapper_classes
    base = if @size == :fullscreen
      "h-full w-full overflow-y-auto bg-white dark:bg-neutral-800 forced-colors:outline"
    else
      "sm:max-w-7xl row-start-2 w-full bg-white dark:bg-neutral-800 forced-colors:outline"
    end
    padding = "p-6"
    rounded = (@size == :fullscreen) ? "" : "rounded-xl lg:rounded-2xl"
    [base, padding, rounded].compact.reject(&:empty?).join(" ")
  end

  def trigger_button_classes
    base = "flex items-center justify-center gap-1.5 rounded-lg border border-black/10 bg-white/90 px-3.5 py-2 text-sm font-medium whitespace-nowrap text-neutral-800 shadow-xs transition-all duration-100 ease-in-out select-none hover:bg-neutral-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-600 disabled:cursor-not-allowed disabled:opacity-50 dark:border-white/10 dark:bg-neutral-700/50 dark:text-neutral-50 dark:hover:bg-neutral-700/75 dark:focus-visible:outline-neutral-200"
    [@trigger_classes, base].compact.reject(&:empty?).join(" ")
  end

  def close_button_classes
    "z-10 p-1.5 absolute right-4 top-5 rounded-full opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-hidden hover:bg-neutral-500/15 active:bg-neutral-500/25 disabled:pointer-events-none"
  end

  def title_classes
    "mb-2 text-lg font-semibold text-neutral-900 dark:text-white"
  end

  def footer_classes
    "flex justify-end items-center flex-wrap gap-2 mt-4"
  end

  def render_close_icon
    icon("x", class: "size-4")
  end

  attr_reader :title, :show_close_button, :prevent_dismiss, :lazy_load, :trigger_text
end
