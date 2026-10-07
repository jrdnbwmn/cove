class Enrollment < ApplicationRecord
  belongs_to :course
  belongs_to :learner

  validate :learner_belongs_to_course_family
  validate :learner_is_not_already_enrolled
  validate :learner_is_active_and_editable, on: :create

  private

  def learner_belongs_to_course_family
    return unless learner && course && learner.account_id != course.account_id

    errors.add(:learner, :wrong_account)
  end

  def learner_is_not_already_enrolled
    return unless learner && course && self.class.where(course: course, learner: learner).where.not(id: id).exists?

    errors.add(:learner, :taken, name: learner.name)
  end

  def learner_is_active_and_editable
    return unless learner

    if learner.archived?
      errors.add(:learner, :archived)
    elsif !learner.editable?
      errors.add(:learner, :read_only, name: learner.name)
    end
  end
end
