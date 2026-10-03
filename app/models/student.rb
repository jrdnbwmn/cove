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

  def archive!
    update!(archived_at: Time.current) unless archived?
  end

  def restore!
    update!(archived_at: nil) if archived?
  end

  private

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
