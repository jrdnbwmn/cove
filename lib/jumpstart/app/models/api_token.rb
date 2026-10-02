class ApiToken < ApplicationRecord
  DEFAULT_NAME = I18n.t("api_tokens.default")
  APP_NAME = I18n.t("api_tokens.app")

  has_prefix_id :token
  has_secure_token :token

  belongs_to :user

  scope :sorted, -> { order(arel_table[:last_used_at].desc.nulls_last, created_at: :desc) }

  validates :name, presence: true

  # AIDEV-NOTE: API clients can make many requests per minute, so persist this
  # activity timestamp no more than once every five minutes to avoid a write per request.
  def touch_last_used!
    touch(:last_used_at) if last_used_at.nil? || last_used_at < 5.minutes.ago
  end

  def can?(permission)
    Array.wrap(data("permissions")).include?(permission)
  end

  def cant?(permission)
    !can?(permission)
  end

  def data(key, default: nil)
    (metadata || {}).fetch(key, default)
  end

  def generate_token
    loop do
      self.token = SecureRandom.hex(16)
      break unless ApiToken.where(token: token).exists?
    end
  end
end
