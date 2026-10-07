class Course < ApplicationRecord
  # AIDEV-NOTE: The UI says "Class", while this model is Course because
  # `class` is reserved in Ruby.
  NAME_MAX_LENGTH = 75
  SUBJECT_MAX_LENGTH = 50
  SUBJECT_SUGGESTIONS = ["Math", "Language Arts", "Science", "Social Studies", "World Languages", "Arts", "Health", "Electives"].freeze

  belongs_to :account
  # AIDEV-NOTE: validate: false because enrollments_are_valid reports enrollment
  # errors on :learners; Rails' own association validation would add a second,
  # duplicate error under "enrollments.learner".
  has_many :enrollments, dependent: :destroy, autosave: true, validate: false
  has_many :learners, through: :enrollments

  normalizes :name, with: ->(name) { name.strip }
  normalizes :subject, with: ->(subject) { subject.strip.presence }

  before_validation :match_subject_spelling

  validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
  validates :subject, length: {maximum: SUBJECT_MAX_LENGTH}
  # AIDEV-NOTE: The select controller parses option text that starts with "{" as JSON and renders its
  # icon/side keys as raw HTML. Subjects are user-typed options, so one starting with "{" would be stored XSS.
  validates :subject, format: {without: /\A\{/}, allow_nil: true
  validate :enrollments_are_valid
  validate :not_completed_and_archived

  # AIDEV-NOTE: Raw SQL because Rails has no scope for case-insensitive ordering with NULLs last.
  scope :ordered, -> { order(Arel.sql("subject IS NULL ASC, lower(subject) ASC, lower(name) ASC")) }

  scope :active, -> { where(completed_at: nil, archived_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :taken_by, ->(learner) { joins(:enrollments).where(enrollments: {learner_id: learner.id}) }
  scope :with_subject, ->(subject) { where("lower(subject) = ?", subject.downcase) }

  # AIDEV-NOTE: Separate from subject_options_for, which mixes in suggestions for the form. The filter only
  # offers subjects the family actually uses, across every status, one spelling per case-insensitive group.
  def self.subject_filter_options_for(account)
    account.courses.where.not(subject: nil).order(:created_at, :id).pluck(:subject)
      .group_by(&:downcase)
      .map { |_, spellings| spellings.tally.max_by { |_, count| count }.first }
      .sort_by(&:downcase)
  end

  def self.subject_options_for(account)
    custom_subjects = account.courses.where.not(subject: nil).distinct.pluck(:subject)
    (SUBJECT_SUGGESTIONS + custom_subjects).uniq { |subject| subject.downcase }
  end

  def active?
    completed_at.nil? && archived_at.nil?
  end

  def completed?
    completed_at.present?
  end

  def archived?
    archived_at.present?
  end

  # AIDEV-NOTE: Each transition locks and reloads the row first, so a stale copy (another parent's change, a
  # double click) is judged against the database. A refused transition adds an error and returns false.
  def complete!
    with_lock do
      if active?
        update!(completed_at: Time.current)
      else
        reject_status_change(completed? ? :already_completed : :not_active)
      end
    end
  end

  def archive!
    with_lock do
      if active?
        update!(archived_at: Time.current)
      else
        reject_status_change(archived? ? :already_archived : :not_active)
      end
    end
  end

  def reopen!
    with_lock do
      completed? ? update!(completed_at: nil) : reject_status_change(:not_completed)
    end
  end

  def restore!
    with_lock do
      archived? ? update!(archived_at: nil) : reject_status_change(:not_archived)
    end
  end

  # AIDEV-NOTE: We cannot use learner_ids= because the picker only includes
  # active learners; Rails would delete enrollments for archived learners.
  def assign_learners(ids)
    selected_learners = account.learners.active.where(id: Array(ids).reject(&:blank?)).to_a
    selected_ids = selected_learners.map(&:id)
    existing_enrollments = enrollments.to_a
    ActiveRecord::Associations::Preloader.new(records: existing_enrollments, associations: :learner).call

    selected_learners.each do |learner|
      enrollments.build(learner: learner) unless existing_enrollments.any? { |enrollment| enrollment.learner_id == learner.id }
    end

    existing_enrollments.each do |enrollment|
      enrollment.mark_for_destruction if !enrollment.learner.archived? && !selected_ids.include?(enrollment.learner_id)
    end
  end

  private

  def reject_status_change(error)
    errors.clear
    errors.add(:base, error, name: name)
    false
  end

  def not_completed_and_archived
    errors.add(:base, :completed_and_archived) if completed_at.present? && archived_at.present?
  end

  def match_subject_spelling
    return if subject.blank?

    matching_subject = SUBJECT_SUGGESTIONS.find { |suggestion| suggestion.casecmp?(subject) }
    matching_subject ||= account&.courses&.where("lower(subject) = ?", subject.downcase)&.pick(:subject)
    self.subject = matching_subject if matching_subject
  end

  def enrollments_are_valid
    enrollments.reject(&:marked_for_destruction?).each do |enrollment|
      next if enrollment.valid?

      enrollment.errors[:learner].each { |message| errors.add(:learners, message) }
    end
  end
end
