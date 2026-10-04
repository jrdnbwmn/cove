class Student < ApplicationRecord
  # AIDEV-NOTE: The database stores only the key; application.css defines a
  # matching --student-<key> token for each, so views never repeat hex values.
  COLORS = %w[sage sea sky lavender rose clay ochre slate].freeze
  MAX_LENGTH = 50

  belongs_to :account

  normalizes :name, with: ->(name) { name.strip }
  normalizes :grade_level, with: ->(grade_level) { grade_level.strip.presence }

  before_validation :assign_color, on: :create

  validates :name, presence: true, length: {maximum: MAX_LENGTH}
  validates :grade_level, length: {maximum: MAX_LENGTH}
  validates :color, inclusion: {in: COLORS}
  validate :name_unique_within_account
  validate :within_student_limit, if: :becoming_active?

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(:created_at, :id) }

  # Least-used color among the family's active students; ties go to the
  # earliest in the palette. Archived students free their color.
  def self.next_color_for(account)
    counts = account.students.active.group(:color).count
    COLORS.min_by.with_index { |color, index| [counts.fetch(color, 0), index] }
  end

  def archived?
    archived_at.present?
  end

  # AIDEV-NOTE: kept_on_free deliberately survives re-subscribing (it only matters while the family is over the Free
  # limit), so a later downgrade reuses the earlier pick. Only archiving or choosing again clears it.
  def editable?
    !account.over_free_student_limit? || kept_on_free?
  end

  def archive!
    update!(archived_at: archived_at || Time.current, kept_on_free: false)
  end

  def restore!
    update!(archived_at: nil) if archived?
  end

  private

  def becoming_active?
    if new_record?
      archived_at.nil?
    else
      archived_at_changed? && archived_at.nil?
    end
  end

  # AIDEV-NOTE: Locking the family row serializes concurrent saves. Validations
  # run inside the save's transaction, so the lock holds until commit and a
  # second parent saving at the same moment re-counts after the first finishes.
  # A restoring student is still archived in the DB here, so it isn't counted.
  def within_student_limit
    return unless account

    account.lock!
    return if account.can_add_student?

    key = account.premium? ? :student_limit_premium : :student_limit_free
    errors.add(:base, key, count: account.students_allowed)
  end

  def assign_color
    self.color = self.class.next_color_for(account) if color.blank? && account
  end

  # AIDEV-NOTE: The unique index is the real guarantee; this gives a friendly
  # message and distinguishes an archived duplicate so the parent knows to restore.
  def name_unique_within_account
    return if name.blank? || account_id.blank?

    existing = Student.where(account_id: account_id).where("lower(name) = ?", name.downcase).where.not(id: id).first
    return unless existing

    errors.add(:name, existing.archived? ? :taken_archived : :taken_active, name: name)
  end
end
