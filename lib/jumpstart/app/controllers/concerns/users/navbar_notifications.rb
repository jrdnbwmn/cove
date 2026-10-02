module Users
  module NavbarNotifications
    extend ActiveSupport::Concern

    included do
      # AIDEV-NOTE: The web navbar never renders notification counts; only Hotwire Native
      # does, so avoid a grouped notifications query on every signed-in web request.
      before_action :set_notification_counts, if: -> { user_signed_in? && hotwire_native_app? }
    end

    def set_notification_counts
      @notification_counts = current_user.notifications.unseen.group(:account_id).count
    end
  end
end
