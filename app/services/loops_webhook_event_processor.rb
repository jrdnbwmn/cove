# AIDEV-NOTE: only a contact.mailingList.unsubscribed for the Cove updates
# list changes state; events for other lists are received and ignored. This
# should not need revisiting when a second mailing list exists — the branch
# already checks the list id.
class LoopsWebhookEventProcessor
  def initialize(config: Rails.application.config_for(:loops))
    @config = config
  end

  def call(event)
    user = find_user(event.payload["contactIdentity"])

    if user.nil?
      Rails.logger.info("LoopsWebhookEventProcessor: no user match for #{event.event_name} (webhook_id=#{event.webhook_id})")
      return
    end

    case event.event_name
    when "contact.unsubscribed", "email.unsubscribed"
      opt_out(user, reason: "user_loops", event_time: event.event_time)
    when "email.spamReported"
      opt_out(user, reason: "spam_report", event_time: event.event_time)
    when "email.hardBounced"
      opt_out(user, reason: "hard_bounce", event_time: event.event_time)
    when "contact.mailingList.unsubscribed"
      return unless event.payload.dig("mailingList", "id") == config.contact_sync_mailing_list_id

      opt_out(user, reason: "mailing_list_unsubscribe", event_time: event.event_time)
    when "email.resubscribed"
      resubscribe(user, event_time: event.event_time)
    end
  end

  private

  attr_reader :config

  def find_user(contact_identity)
    contact_identity ||= {}

    if (user_id = contact_identity["userId"]).present?
      user = User.find_by(id: user_id)
      return user if user
    end

    if (email = contact_identity["email"]).present?
      return User.find_by(email: email)
    end

    nil
  end

  def opt_out(user, reason:, event_time:)
    return if event_time.present? && user.marketing_opt_in_at.present? && user.marketing_opt_in_at > event_time

    user.reload
    user.record_loops_opt_out(reason: reason, occurred_at: event_time || Time.current)
  end

  def resubscribe(user, event_time:)
    return if event_time.present? && user.marketing_opt_out_at.present? && user.marketing_opt_out_at > event_time

    user.reload
    user.grant_marketing_consent(source: "loops")
  end
end
