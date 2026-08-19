# AIDEV-NOTE: The environment/config gate and consent check are re-asserted
# here even though the only caller (LoopsContactSyncJob) already guarantees
# both — a gate that holds only via its caller is one refactor from not
# holding. No contact fields (email, contact_properties, mailing_lists) are
# ever passed: this emitter's sole job is the event call, never a write to
# the contact record.
class LoopsEventEmitter
  include LoopsContactGate

  EVENT_PROPERTIES = {
    "user_signed_up" => ->(user) { {signed_up_at: user.created_at.iso8601} }
  }.freeze

  def emit(user, event_name)
    return unless production? && contact_sync_enabled?
    return unless current_app_opt_in?(user)

    property_builder = EVENT_PROPERTIES.fetch(event_name) { raise ArgumentError, "unknown loops event: #{event_name}" }

    client.send_event(
      event_name: event_name,
      user_id: user.id.to_s,
      event_properties: property_builder.call(user),
      idempotency_key: Digest::SHA256.hexdigest("#{event_name}:#{user.id}")
    )
  end
end
