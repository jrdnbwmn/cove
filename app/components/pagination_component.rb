# frozen_string_literal: true

class PaginationComponent < ViewComponent::Base
  # AIDEV-NOTE: Rails Blocks generated Pagination::Component; keep this app's catalog flat.
  VARIANTS = %i[full compact minimal].freeze
  SIZES = %i[sm md lg].freeze

  # @param pagy [Pagy] The Pagy pagination object
  # @param variant [Symbol] Display variant: :full (numbered), :compact (prev/next with info), :minimal (prev/next only)
  # @param size [Symbol] Size variant: :sm, :md, :lg
  # @param frame_id [String] Turbo Frame ID for SPA navigation
  # @param show_info [Boolean] Show "Showing X-Y of Z" info text
  # @param show_page_form [Boolean] Show "Jump to page" form (only with :full variant)
  # @param show_limit_form [Boolean] Show rows per page selector
  # @param limit_options [Array<Integer>] Options for rows per page selector
  # @param preserve_params [Hash] Query params to preserve across page changes
  # @param request_path [String] Custom request path for forms
  # @param classes [String] Additional CSS classes for the wrapper
  def initialize(
    pagy:,
    variant: :full,
    size: :md,
    frame_id: nil,
    show_info: true,
    show_page_form: false,
    show_limit_form: false,
    limit_options: [10, 25, 50],
    preserve_params: {},
    request_path: nil,
    classes: nil
  )
    super()
    @pagy = pagy
    @variant = VARIANTS.include?(variant) ? variant : :full
    @size = SIZES.include?(size) ? size : :md
    @frame_id = frame_id
    @show_info = show_info
    @show_page_form = show_page_form && @variant == :full
    @show_limit_form = show_limit_form
    @limit_options = limit_options.map(&:to_i)
    @preserve_params = preserve_params
    @request_path = request_path
    @classes = classes
  end

  def wrapper_classes
    base = "flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
    [@classes, base].compact.reject(&:empty?).join(" ")
  end

  def nav_wrapper_classes
    "inline-flex items-center gap-2 text-sm font-medium"
  end

  def info_classes
    case @size
    when :sm then "text-xs text-neutral-600 dark:text-neutral-300"
    when :lg then "text-base text-neutral-600 dark:text-neutral-300"
    else "text-sm text-neutral-600 dark:text-neutral-300"
    end
  end

  def page_key
    @pagy.options[:page_key] || "page"
  end

  def limit_key
    @pagy.options[:limit_key] || "limit"
  end

  def query_params
    @query_params ||= begin
      params = @preserve_params.stringify_keys.except(page_key.to_s, limit_key.to_s)
      params[limit_key] = @pagy.limit.to_s
      params
    end
  end

  def anchor_string
    @frame_id.present? ? "data-turbo-frame='#{@frame_id}'" : nil
  end

  def prev_url
    return nil unless @pagy.previous

    @pagy.page_url(@pagy.previous, querify: ->(q) { q.merge!(query_params) })
  end

  def next_url
    return nil unless @pagy.next

    @pagy.page_url(@pagy.next, querify: ->(q) { q.merge!(query_params) })
  end

  def nav_html
    common_opts = {
      anchor_string: anchor_string,
      querify: ->(q) { q.merge!(query_params) }
    }.compact

    @pagy.series_nav(**common_opts)
  end

  def prev_html
    common_opts = {
      anchor_string: anchor_string,
      querify: ->(q) { q.merge!(query_params) },
      aria_label: "Previous"
    }.compact

    @pagy.previous_tag(**common_opts)
  end

  def next_html
    common_opts = {
      anchor_string: anchor_string,
      querify: ->(q) { q.merge!(query_params) },
      aria_label: "Next"
    }.compact

    @pagy.next_tag(**common_opts)
  end

  def form_path
    @request_path || helpers.request.path
  end

  # Icons
  def prev_icon
    icon("chevron-left", class: icon_size_class)
  end

  def next_icon
    icon("chevron-right", class: icon_size_class)
  end

  private

  def icon_size_class
    case @size
    when :sm then "size-3"
    when :lg then "size-5"
    else "size-4"
    end
  end
end
