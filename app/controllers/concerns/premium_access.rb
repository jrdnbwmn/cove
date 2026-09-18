module PremiumAccess
  extend ActiveSupport::Concern

  included do
    helper_method :premium?
  end

  def premium?
    user_signed_in? && current_account&.premium?
  end

  def require_premium!
    redirect_to pricing_path, notice: t("premium_access.required") unless premium?
  end
end
