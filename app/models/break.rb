class Break < ApplicationRecord
  belongs_to :school_year

  OVERLAP_ERROR = "This overlaps other time off."
  STARTED_DELETE_ERROR = "Time off that has started can't be deleted."

  scope :ordered, -> { order(:starts_on, :id) }
  scope :overlapping, ->(first_day, last_day) { where(starts_on: ..last_day, ends_on: first_day..) }

  validates :name, presence: {message: "Add a name."}, length: {maximum: 100, message: "Use 100 characters or fewer."}
  validates :starts_on, :ends_on, presence: true
  validates :source, inclusion: {in: %w[default added repeating]}
  validate :dates_are_valid
  validate :does_not_overlap
  validate :past_days_are_protected
  before_destroy :protect_started_entry

  # AIDEV-NOTE: Undo posts these signed attributes back through create, so the restore is re-validated
  # like any new entry. The year id ties the token to one family.
  def restore_token
    attributes = {school_year_id:, name:, starts_on: starts_on.iso8601, ends_on: ends_on.iso8601, source:}
    self.class.restore_verifier.generate(attributes, purpose: :time_off_restore, expires_in: 1.week)
  end

  def self.restore_attributes(token, school_year)
    data = restore_verifier.verified(token.to_s, purpose: :time_off_restore)&.with_indifferent_access
    return unless data && data[:school_year_id] == school_year.id

    {name: data[:name], starts_on: Date.iso8601(data[:starts_on]), ends_on: Date.iso8601(data[:ends_on]), source: data[:source]}
  rescue ArgumentError
    nil
  end

  def self.restore_verifier = Rails.application.message_verifier(:time_off_restore)

  def overlaps
    return self.class.none unless school_year && starts_on && ends_on

    school_year.breaks.where.not(id: id).overlapping(starts_on, ends_on).ordered
  end

  def started?
    start_date = persisted? ? starts_on_in_database : starts_on
    start_date.present? && start_date <= school_year.account.today
  end

  # Whether a parent can still open this entry to change it.
  def editable?
    !school_year.ended? && ends_on >= school_year.account.today
  end

  def deletable?
    persisted? && !started? && !school_year.ended?
  end

  # Replace deletes the conflicts, so it only applies while none of them has started.
  def replaceable?(conflicts)
    conflicts.any? && conflicts.none?(&:started?) && !school_year.ended?
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
    errors.add(:base, SchoolYear::ENDED_ERROR) if school_year.ended?
    if new_record? || !started?
      errors.add(:starts_on, "Choose a start date from today on.") if starts_on && starts_on < today
    else
      if will_save_change_to_starts_on? || will_save_change_to_school_year_id? || will_save_change_to_source?
        errors.add(:starts_on, "Already started. You can change the end date.")
      end
      errors.add(:ends_on, "The end can't be before today.") if ends_on && ends_on < today
    end
  end

  def protect_started_entry
    # AIDEV-NOTE: Family deletion must remove its historical records too.
    return if destroyed_by_association
    return if deletable?

    errors.add(:base, STARTED_DELETE_ERROR)
    throw :abort
  end
end
