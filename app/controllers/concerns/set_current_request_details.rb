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
    Current.account ||= account_from_domain || account_from_subdomain || current_user&.family
  end

  def set_fallback_account
    Current.account ||= current_user&.create_default_account if user_signed_in?
  end

  def account_from_domain
    return unless Jumpstart::Multitenancy.domain?

    Account.includes(:payment_processor, :users).find_by(domain: request.host)
  end

  def account_from_subdomain
    return unless Jumpstart::Multitenancy.subdomain? && request.subdomains.size > 0

    Account.includes(:payment_processor, :users).find_by(subdomain: request.subdomains.first)
  end
end
