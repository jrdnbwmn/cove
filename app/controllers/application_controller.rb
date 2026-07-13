class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Accounts::SubscriptionStatus, ActiveStorage::SetCurrent, Authentication, Authorization, DeviceFormat, Pagination, SetCurrentRequestDetails, SetLocale, Sortable, Users::AgreementUpdates, Users::NavbarNotifications, Users::Sudo
end
