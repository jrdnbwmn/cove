module ApplicationHelper
  # AIDEV-NOTE: Single source of truth for mapping a flash key (:notice, :success, :alert, :error)
  # or a toast icon_name (:notice, :success, :alert, :default) to an AlertComponent/toast variant.
  FLASH_VARIANTS = {notice: :info, success: :success, alert: :error, error: :error, default: :default}.freeze

  def flash_variant(key)
    FLASH_VARIANTS.fetch(key.to_sym, :default)
  end
end
