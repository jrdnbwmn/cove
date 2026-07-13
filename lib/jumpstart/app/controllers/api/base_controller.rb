class Api::BaseController < ActionController::API
  include AbstractController::Translation
  include ActionController::Caching
  include Turbo::Native::Navigation

  include Accounts::SubscriptionStatus
  include ActiveStorage::SetCurrent
  include Authentication
  include Authorization
  include Pagy::Method
  include SetCurrentRequestDetails
  include SetLocale
  include Sortable

  prepend_before_action :require_api_authentication, unless: -> { user_signed_in? }

  skip_before_action :set_fallback_account
  before_action :set_account_from_param

  helper :all

  private

  def require_api_authentication
    if (user = user_from_token)
      sign_in user, store: false
    else
      head :unauthorized
    end
  end

  def user_from_token = api_token&.tap { it.touch(:last_used_at) }&.user

  def api_token
    @_api_token ||= ApiToken.find_by(token: token_from_header)
  end

  def token_from_header = request.headers.fetch("Authorization", "").split(" ").last

  def set_account_from_param
    if (account_id = params[:account_id].presence)
      Current.account ||= current_user.accounts.find_by_prefix_id(account_id)
    end
  end
end
