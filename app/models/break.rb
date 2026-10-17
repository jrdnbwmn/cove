class Break < ApplicationRecord
  belongs_to :school_year

  OVERLAP_ERROR = "This overlaps other time off."
  STARTED_DELETE_ERROR = "Time off that has started can't be deleted."

  scope :ordered, -> { order(:starts_on, :id) }

  validates :name, presence: {message: "Add a name."}
  validates :starts_on, :ends_on, presence: true
  validates :source, inclusion: {in: %w[default added repeating]}
  validate :dates_are_valid
  validate :does_not_overlap
  validate :past_days_are_protected
  before_destroy :protect_started_entry

  def overlaps
    return self.class.none unless school_year && starts_on && ends_on

    school_year.breaks.where.not(id: id).where("starts_on <= ? AND ends_on >= ?", ends_on, starts_on).ordered
  end

  def started?
    start_date = persisted? ? starts_on_in_database : starts_on
    start_date.present? && start_date <= school_year.account.today
  end

  private

  def dates_are_valid
    return unless school_year && starts_on && ends_on

    errors.add(:ends_on, "End on or after the start date.") if ends_on < starts_on
    if starts_on < school_year.starts_on || ends_on > school_year.ends_on
      errors.add(:base, "Choose dates inside your school year (#{school_year.starts_on.strftime("%-d %b %Y")}–#{school_year.ends_on.strftime("%-d %b %Y")}).")
    end
  end

  def does_not_overlap
    errors.add(:base, OVERLAP_ERROR) if overlaps.exists?
  end

  def past_days_are_protected
    return unless school_year

    today = school_year.account.today
    errors.add(:base, "This year has ended.") if school_year.ended?
    if new_record? || !started?
      errors.add(:starts_on, "Choose a start date from today on.") if starts_on && starts_on < today
    elsif started?
      if will_save_change_to_starts_on? || will_save_change_to_school_year_id? || will_save_change_to_source?
        errors.add(:starts_on, "Already started. You can change the end date.")
      end
      errors.add(:ends_on, "The end can't be before today.") if ends_on && ends_on < today
    end
  end

  def protect_started_entry
    # AIDEV-NOTE: Family deletion must remove its historical records too.
    return if destroyed_by_association
    return unless started? || school_year.ended?

    errors.add(:base, STARTED_DELETE_ERROR)
    throw :abort
  end
end
