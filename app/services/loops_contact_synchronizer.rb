# AIDEV-NOTE: Three public methods (not the usual single-`call` service
# shape) by design — this is the single owner of Loops contact payload
# construction across sync, delete, and backfill-readiness, per the COV-51
# design doc.
class LoopsContactSynchronizer
  include LoopsContactGate

  class ConfigurationError < StandardError; end
  class ProductionRequired < ConfigurationError; end
  class ContactSyncDisabled < ConfigurationError; end
  class MailingListMissing < ConfigurationError; end

  def sync(user, intent:, previously_consented: nil)
    return unless contact_sync_allowed?

    case intent.to_sym
    when :opt_in
      ensure_mailing_list_configured!
      return unless current_app_opt_in?(user)

      client.update_contact(**subscribed_attributes(user))
    when :opt_out
      ensure_mailing_list_configured!
      return unless current_app_opt_out?(user)

      client.update_contact(**unsubscribed_attributes(user))
    when :email_change
      return unless previously_consented.nil? ? user.marketing_opt_in_at.present? : previously_consented

      client.update_contact(email: user.email, user_id: user.id.to_s)
    else
      raise ArgumentError, "unknown contact sync intent: #{intent}"
    end
  end

  def delete(user_id)
    return unless contact_sync_allowed?

    client.delete_contact(user_id: user_id.to_s)
  rescue LoopsClient::NotFound
    nil
  end

  def ensure_backfill_ready!
    raise ProductionRequired, "Loops contact backfill requires production" unless production?
    raise ContactSyncDisabled, "Loops contact sync is disabled" unless contact_sync_enabled?
    raise MailingListMissing, "Loops contact sync mailing list is not configured" if mailing_list_id.blank?

    true
  end

  private

  def contact_sync_allowed?
    production? && contact_sync_enabled?
  end

  def mailing_list_id
    config.contact_sync_mailing_list_id
  end

  def current_app_opt_out?(user)
    return false if user.marketing_subscribed?
    return false unless user.marketing_opt_out_reason == "user_app"

    true
  end

  def ensure_mailing_list_configured!
    raise MailingListMissing, "Loops contact sync mailing list is not configured" if mailing_list_id.blank?
  end

  def subscribed_attributes(user)
    {
      email: user.email,
      user_id: user.id.to_s,
      subscribed: true,
      mailing_lists: {mailing_list_id => true}
    }
  end

  def unsubscribed_attributes(user)
    {
      user_id: user.id.to_s,
      subscribed: false,
      mailing_lists: {mailing_list_id => false}
    }
  end
end
