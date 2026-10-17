# A word of caution: It's easy to overdo a global singleton like Current and tangle your model as a result.
# Current should only be used for a few, top-level globals, like account, user, and request details.
# The attributes stuck in Current should be used by more or less all actions on all requests.
# If you start sticking controller-specific attributes in there, you're going to create a mess.

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :request_id, :user_agent, :ip_address
  attribute :meta_tags, default: MetaTags.new

  resets do
    Time.zone = nil
  end

  def user=(value)
    super
    apply_time_zone
  end

  def account=(value)
    super
    @account_user = nil
    @other_accounts = nil
    apply_time_zone
  end

  def account_user
    return unless account
    @account_user ||= account.account_users.find_by(user: user)
  end

  def roles = Array.wrap(account_user&.active_roles)

  def account_admin? = !!account_user&.admin?

  def other_accounts
    @other_accounts ||= user.present? ? user.accounts.order(name: :asc).where.not(id: account.id) : Account.none
  end

  private

  # AIDEV-NOTE: The family's zone wins over the parent's, so both parents see the same day.
  def apply_time_zone
    Time.zone = Time.find_zone(account&.time_zone || user&.time_zone)
  end
end
