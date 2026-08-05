# AIDEV-NOTE: 30-day retention must outlive Loops' 24-hour retry window,
# because Webhook-Id dedupe (the unique index) is the only replay defence.
class LoopsWebhookEvent < ApplicationRecord
  RETENTION = 30.days

  scope :prunable, -> { where(created_at: ...RETENTION.ago) }
  scope :unprocessed, -> { where(processed_at: nil) }

  # AIDEV-NOTE: Loops documents eventTime only as "Unix timestamp"; the
  # millisecond threshold below is a defensive guess, not a documented contract.
  def self.parse_event_time(value)
    return nil if value.blank?

    value = value.to_i
    value /= 1000 if value > 100_000_000_000
    Time.at(value)
  end

  def processed!
    update!(processed_at: Time.current)
  end
end
