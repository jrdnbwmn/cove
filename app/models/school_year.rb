class SchoolYear < ApplicationRecord
  include Counting
  include Defaults

  belongs_to :account
  has_many :breaks, dependent: :destroy

  scope :active, -> { where(status: "active") }

  validates :starts_on, :ends_on, presence: true
  validates :status, inclusion: {in: %w[active]}
  validates :account_id, uniqueness: {conditions: -> { where(status: "active") }}, if: :active?
  validate :dates_are_valid
  validate :weekdays_are_valid
  validate :past_days_are_protected, on: :update
  before_save :remember_previous_weekdays

  def active?
    status == "active"
  end

  def ended?
    ends_on.present? && ends_on < account.today
  end

  private

  def dates_are_valid
    return unless starts_on && ends_on

    errors.add(:ends_on, "End the year after it starts.") if ends_on <= starts_on
    errors.add(:ends_on, "The year can be up to 12 months.") if ends_on > starts_on.advance(years: 1)
  end

  def weekdays_are_valid
    if school_weekdays.blank?
      errors.add(:school_weekdays, "Choose at least one school day.")
    elsif school_weekdays.any? { |day| !day.in?(0..6) }
      errors.add(:school_weekdays, "Choose valid school days.")
    end
  end

  def past_days_are_protected
    today = account.today
    if ends_on_in_database < today
      errors.add(:base, "This year has ended.")
      return
    end

    if will_save_change_to_starts_on? && starts_on && starts_on_in_database <= today
      if tracked_from_in_database.nil? || starts_on > starts_on_in_database
        errors.add(:starts_on, "The year has started. You can only move the start earlier.")
      end
    end
    if ends_on
      errors.add(:ends_on, "The end can't be before today.") if ends_on < today
      last_break = breaks.order(ends_on: :desc).first
      if last_break && last_break.ends_on > ends_on
        errors.add(:ends_on, "#{last_break.name} ends after this date. Change it first.")
      end
    end
  end

  def remember_previous_weekdays
    return unless persisted? && will_save_change_to_school_weekdays?

    yesterday = account.today - 1
    return if starts_on_in_database > yesterday
    return if weekday_history.last&.fetch("through") == yesterday.iso8601

    # AIDEV-NOTE: Run only after validation so retries cannot accumulate history.
    self.weekday_history = weekday_history + [{"through" => yesterday.iso8601, "days" => school_weekdays_in_database}]
  end
end
