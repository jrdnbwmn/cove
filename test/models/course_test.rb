require "test_helper"

class CourseTest < ActiveSupport::TestCase
  class CourseRow < ApplicationRecord
    self.table_name = "courses"
  end

  def row_attributes(overrides = {})
    {account_id: accounts(:company).id, name: "Algebra 1"}.merge(overrides)
  end

  test "database requires a family and name" do
    %i[account_id name].each do |column|
      assert_raises(ActiveRecord::NotNullViolation, "#{column} should be required") do
        CourseRow.new(row_attributes(column => nil)).save!(validate: false)
      end
    end
  end

  test "database rejects a class for a family that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      CourseRow.create!(row_attributes(account_id: 0))
    end
  end
end

class CourseBehaviorTest < ActiveSupport::TestCase
  setup do
    @family = accounts(:subscribed)
    @other_family = accounts(:one)
  end

  def build_course(attributes = {})
    Course.new({account: @family, name: "Algebra 1"}.merge(attributes))
  end

  test "a class can be saved with only a name" do
    assert build_course.valid?
  end

  test "class names and subjects are stripped and a blank subject is removed" do
    course = Course.create!(account: @family, name: "  Algebra 1  ", subject: "  Science  ")
    assert_equal "Algebra 1", course.name
    assert_equal "Science", course.subject

    course.update!(subject: "   ")
    assert_nil course.subject
  end

  test "a class name and subject have their intended maximum lengths" do
    assert build_course(name: "a" * 75, subject: "b" * 50).valid?

    course = build_course(name: "a" * 76, subject: "b" * 51)
    assert_not course.valid?
    assert_equal ["Use 75 characters or fewer."], course.errors[:name]
    assert_equal ["Use 50 characters or fewer."], course.errors[:subject]
  end

  test "two classes can have the same name" do
    Course.create!(account: @family, name: "Algebra 1")
    assert build_course.valid?
  end

  test "suggested subjects use their preferred spelling" do
    course = Course.create!(account: @family, name: "Algebra 1", subject: "math")
    assert_equal "Math", course.subject
  end

  test "a custom family subject uses its existing spelling without using another family's subject" do
    Course.create!(account: @family, name: "Co-op Biology", subject: "Co-op")
    Course.create!(account: @other_family, name: "Other", subject: "Different spelling")

    course = Course.create!(account: @family, name: "Co-op Lab", subject: "co-op")
    assert_equal "Co-op", course.subject
    assert_not_includes Course.subject_options_for(@family), "Different spelling"
  end

  test "subject options combine suggestions with this family's custom subjects once" do
    Course.create!(account: @family, name: "One", subject: "Co-op")
    Course.create!(account: @family, name: "Two", subject: "co-op")
    Course.create!(account: @other_family, name: "Other", subject: "Other family")

    options = Course.subject_options_for(@family)
    assert_equal Course::SUBJECT_SUGGESTIONS, options.first(Course::SUBJECT_SUGGESTIONS.length)
    assert_equal 1, options.count { |subject| subject.casecmp?("co-op") }
    assert_not_includes options, "Other family"
  end

  test "classes are ordered by subject and name with no subject last" do
    science = Course.create!(account: @family, name: "Zoology", subject: "Science")
    algebra = Course.create!(account: @family, name: "Algebra", subject: "Math")
    art = Course.create!(account: @family, name: "Art", subject: "Arts")
    no_subject = Course.create!(account: @family, name: "Piano")

    assert_equal [art, algebra, science, no_subject], @family.courses.ordered.to_a
  end

  test "a class can have several learners or none" do
    maya = Learner.create!(account: @family, name: "Maya")
    theo = Learner.create!(account: @family, name: "Theo")
    course = Course.new(account: @family, name: "Algebra 1")
    course.assign_learners([maya.id, theo.id])

    assert course.save
    assert_equal [maya, theo], course.learners.order(:id).to_a

    course.assign_learners([])
    assert course.save
    assert_empty course.reload.learners
  end

  test "checking learners adds them to a class" do
    maya = Learner.create!(account: @family, name: "Maya")
    course = Course.create!(account: @family, name: "Algebra 1")

    course.assign_learners([maya.id])
    assert course.save
    assert_equal [maya], course.reload.learners.to_a
  end

  test "other-family and archived learners submitted to a class are ignored" do
    course = Course.new(account: accounts(:company), name: "Algebra 1")
    course.assign_learners([learners(:kept).id, learners(:archived).id])

    assert course.save
    assert_empty course.reload.learners
  end

  test "an archived learner enrollment survives saving and reappears after restore" do
    active = Learner.create!(account: @family, name: "Maya")
    archived = Learner.create!(account: @family, name: "Iris")
    course = Course.create!(account: @family, name: "Algebra 1")
    Enrollment.create!(course: course, learner: archived)
    archived.archive!
    course.assign_learners([active.id])

    assert course.save
    assert_not_includes course.reload.visible_learners, archived
    assert_includes course.learners, archived

    archived.restore!
    assert_includes course.reload.visible_learners, archived
  end

  test "a read-only learner makes the class save fail without persisting changes" do
    family = accounts(:downgraded)
    course = Course.new(account: family, name: "Algebra 1")
    course.assign_learners([learners(:read_only).id])

    assert_no_difference ["Course.count", "Enrollment.count"] do
      assert_not course.save
    end
    assert_equal ["Casey is read-only on Free, so they can't be added to a class."], course.errors[:learners]
  end

  test "a read-only learner already enrolled can be unchecked" do
    course = courses(:downgraded_course)
    course.assign_learners([learners(:kept).id])

    assert course.save
    assert_equal [learners(:kept)], course.reload.learners.to_a
  end
end
