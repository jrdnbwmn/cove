require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  class EnrollmentRow < ApplicationRecord
    self.table_name = "enrollments"
  end

  class CourseRow < ApplicationRecord
    self.table_name = "courses"
  end

  def row_attributes(overrides = {})
    {course_id: course.id, learner_id: learners(:one).id}.merge(overrides)
  end

  def course
    @course ||= CourseRow.create!(account_id: accounts(:company).id, name: "Algebra 1")
  end

  test "database requires a class and learner" do
    %i[course_id learner_id].each do |column|
      assert_raises(ActiveRecord::NotNullViolation, "#{column} should be required") do
        EnrollmentRow.new(row_attributes(column => nil)).save!(validate: false)
      end
    end
  end

  test "database rejects enrollments for missing records" do
    %i[course_id learner_id].each do |column|
      assert_raises(ActiveRecord::InvalidForeignKey) do
        EnrollmentRow.create!(row_attributes(column => 0))
      end
    end
  end

  test "database rejects a duplicate learner in the same class" do
    EnrollmentRow.create!(row_attributes)

    assert_raises(ActiveRecord::RecordNotUnique) do
      EnrollmentRow.create!(row_attributes)
    end
  end

  test "a learner from another family cannot join a class" do
    enrollment = Enrollment.new(course: courses(:one), learner: learners(:kept))

    assert_not enrollment.valid?
    assert_includes enrollment.errors[:learner], "must belong to the same family as the class"
  end

  test "a learner cannot be added twice to the same class" do
    Enrollment.create!(course: courses(:one), learner: learners(:one))
    duplicate = Enrollment.new(course: courses(:one), learner: learners(:one))

    assert_not duplicate.valid?
    assert_equal ["Maya is already in this class."], duplicate.errors[:learner]
  end

  test "an archived learner cannot be added to a class" do
    enrollment = Enrollment.new(course: courses(:one), learner: learners(:archived))

    assert_not enrollment.valid?
    assert_includes enrollment.errors[:learner], "must be active to be added to a class"
  end

  test "a read-only learner cannot be added to a class" do
    enrollment = Enrollment.new(course: courses(:downgraded_course), learner: learners(:read_only_two))

    assert_not enrollment.valid?
    assert_equal ["Dakota is read-only on Free, so they can't be added to a class."], enrollment.errors[:learner]
  end

  test "an existing enrollment for a read-only learner remains valid and can be deleted" do
    enrollment = enrollments(:downgraded_read_only)

    assert enrollment.valid?
    assert enrollment.destroy
  end
end
