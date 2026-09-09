module Users::SignupCompletion
  extend ActiveSupport::Concern

  included do
    before_action :require_signup_completion!, if: -> { request.get? && user_signed_in? && !devise_controller? }
  end

  def require_signup_completion!
    return unless current_user.signup_completion_required?

    store_location_for(:user, request.fullpath) unless request.fullpath.start_with?("/signup_completion")
    redirect_to signup_completion_path
  end
end
