module SetCurrentRequestDetails
  extend ActiveSupport::Concern

  included do |base|
    if base < ActionController::Metal
      set_current_tenant_through_filter if defined? ActsAsTenant
      before_action :set_request_details
      before_action :set_fallback_account
      before_action -> { set_current_tenant(Current.account) } if defined?(ActsAsTenant)
    end
  end

  def set_request_details
    Current.request_id = request.uuid
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
    Current.user = current_user

    # Account may already be set by the AccountMiddleware
    Current.account ||= account_from_domain || account_from_subdomain || account_from_cookie
  end

  def set_fallback_account
    Current.account ||= fallback_account
  end

  def account_from_domain
    return unless Jumpstart::Multitenancy.domain?
    Account.includes(:payment_processor, :users).find_by(domain: request.host)
  end

  def account_from_subdomain
    return unless Jumpstart::Multitenancy.subdomain? && request.subdomains.size > 0
    Account.includes(:payment_processor, :users).find_by(subdomain: request.subdomains.first)
  end

  # API controllers don't support cookies
  def account_from_cookie
    return unless Jumpstart::Multitenancy.session? && respond_to?(:cookies, true) && user_signed_in? && (account_id = cookies.signed[:account_id])
    current_user.accounts.includes(:payment_processor, :users).find_by(id: account_id)
  end

  # Returns an account sorting by personal accounts and oldest account first
  def fallback_account
    return unless user_signed_in?
    current_user.accounts.includes(:payment_processor, :users).order(personal: :desc, created_at: :asc).first || current_user.create_default_account
  end
end
