class Course < ApplicationRecord
  # AIDEV-NOTE: The UI says "Class", while this model is Course because
  # `class` is reserved in Ruby.
  NAME_MAX_LENGTH = 75
  SUBJECT_MAX_LENGTH = 50
  SUBJECT_SUGGESTIONS = ["Math", "Language Arts", "Science", "Social Studies", "World Languages", "Arts", "Health", "Electives"].freeze

  belongs_to :account
  has_many :enrollments, dependent: :destroy
  has_many :learners, through: :enrollments

  normalizes :name, with: ->(name) { name.strip }
  normalizes :subject, with: ->(subject) { subject.strip.presence }

  before_validation :match_subject_spelling

  validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
  validates :subject, length: {maximum: SUBJECT_MAX_LENGTH}

  scope :ordered, -> { order(Arel.sql("subject IS NULL ASC, lower(subject) ASC, lower(name) ASC")) }

  def self.subject_options_for(account)
    custom_subjects = account.courses.where.not(subject: nil).pluck(:subject)
    (SUBJECT_SUGGESTIONS + custom_subjects).uniq { |subject| subject.downcase }
  end

  private

  def match_subject_spelling
    return if subject.blank?

    matching_subject = SUBJECT_SUGGESTIONS.find { |suggestion| suggestion.casecmp?(subject) }
    matching_subject ||= account&.courses&.where("lower(subject) = ?", subject.downcase)&.pick(:subject)
    self.subject = matching_subject if matching_subject
  end
end
