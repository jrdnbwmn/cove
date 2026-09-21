class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Accounts::SubscriptionStatus, ActiveStorage::SetCurrent, Authentication, Authorization, DeviceFormat, Pagination, PremiumAccess, SetCurrentRequestDetails, SetLocale, Sortable, Users::AgreementUpdates, Users::NavbarNotifications, Users::SignupCompletion, Users::Sudo

  helper_method :marketing_page?

  private

  # AIDEV-NOTE: Explicit controller#action list, not a controller check, because
  # PublicController also serves /about, /terms, /privacy, which keep the standard navbar.
  MARKETING_PAGES = %w[public#index pricing#show].freeze

  def marketing_page?
    MARKETING_PAGES.include?("#{controller_name}##{action_name}")
  end
end
