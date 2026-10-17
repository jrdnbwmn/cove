class SchoolYear < ApplicationRecord
  belongs_to :account
  has_many :breaks, dependent: :destroy

  scope :active, -> { where(status: "active") }

  validates :starts_on, :ends_on, presence: true
  validates :status, inclusion: {in: %w[active]}
  validates :account_id, uniqueness: {conditions: -> { where(status: "active") }}, if: :active?
  validate :dates_are_valid
  validate :weekdays_are_valid

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
end
