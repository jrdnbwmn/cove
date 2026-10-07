class Course < ApplicationRecord
  # AIDEV-NOTE: The UI says "Class", while this model is Course because
  # `class` is reserved in Ruby.
  NAME_MAX_LENGTH = 75
  SUBJECT_MAX_LENGTH = 50
  SUBJECT_SUGGESTIONS = ["Math", "Language Arts", "Science", "Social Studies", "World Languages", "Arts", "Health", "Electives"].freeze

  belongs_to :account
  has_many :enrollments, dependent: :destroy, autosave: true
  has_many :learners, through: :enrollments

  normalizes :name, with: ->(name) { name.strip }
  normalizes :subject, with: ->(subject) { subject.strip.presence }

  before_validation :match_subject_spelling

  validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
  validates :subject, length: {maximum: SUBJECT_MAX_LENGTH}
  validate :enrollments_are_valid

  scope :ordered, -> { order(Arel.sql("subject IS NULL ASC, lower(subject) ASC, lower(name) ASC")) }

  def self.subject_options_for(account)
    custom_subjects = account.courses.where.not(subject: nil).pluck(:subject)
    (SUBJECT_SUGGESTIONS + custom_subjects).uniq { |subject| subject.downcase }
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

  def visible_learners
    learners.active.ordered
  end

  private

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
