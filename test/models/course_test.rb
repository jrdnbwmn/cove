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

class CourseStatusConstraintTest < ActiveSupport::TestCase
  class CourseRow < ApplicationRecord
    self.table_name = "courses"
  end

  test "database rejects a class that is both completed and archived" do
    assert_raises(ActiveRecord::StatementInvalid) do
      CourseRow.create!(account_id: accounts(:company).id, name: "Both", completed_at: Time.current, archived_at: Time.current)
    end
  end

  test "database allows a class that is only completed or only archived" do
    assert CourseRow.create!(account_id: accounts(:company).id, name: "Done", completed_at: Time.current)
    assert CourseRow.create!(account_id: accounts(:company).id, name: "Old", archived_at: Time.current)
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

  test "a subject cannot start with a curly brace" do
    course = build_course(subject: %({"icon":"<img src=x onerror=alert(1)>"}))

    assert_not course.valid?
    assert_equal ["Start the subject with a letter or number."], course.errors[:subject]
    assert build_course(subject: "Latin {advanced}").valid?
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
    assert_not_includes course.reload.learners.active, archived
    assert_includes course.learners, archived

    archived.restore!
    assert_includes course.reload.learners.active, archived
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

  test "a new class is active" do
    course = Course.create!(account: @family, name: "Algebra 1")

    assert course.active?
    assert_not course.completed?
    assert_not course.archived?
    assert_includes Course.active, course
  end

  test "a parent can complete a class right away and reopen it" do
    course = Course.create!(account: @family, name: "Algebra 1")

    assert course.complete!
    assert course.reload.completed?
    assert_includes Course.completed, course
    assert_not_includes Course.active, course

    assert course.reopen!
    assert course.reload.active?
    assert_nil course.completed_at
  end

  test "a parent can archive a class and restore it" do
    course = Course.create!(account: @family, name: "Algebra 1")

    assert course.archive!
    assert course.reload.archived?
    assert_includes Course.archived, course
    assert_not_includes Course.active, course

    assert course.restore!
    assert course.reload.active?
    assert_nil course.archived_at
  end

  test "only an active class can be completed or archived" do
    completed = courses(:completed)
    archived = courses(:archived)

    assert_no_changes -> { [completed.reload.completed_at, completed.archived_at] } do
      assert_not completed.complete!
      assert_equal ["#{completed.name} is already completed."], completed.errors[:base]
      assert_not completed.archive!
      assert_equal ["Only an active class can be completed or archived."], completed.errors[:base]
    end

    assert_no_changes -> { [archived.reload.completed_at, archived.archived_at] } do
      assert_not archived.archive!
      assert_equal ["#{archived.name} is already archived."], archived.errors[:base]
      assert_not archived.complete!
      assert_equal ["Only an active class can be completed or archived."], archived.errors[:base]
    end
  end

  test "only a completed class can be reopened and only an archived class restored" do
    active = courses(:one)
    completed = courses(:completed)
    archived = courses(:archived)

    assert_not active.reopen!
    assert_not archived.reopen!
    assert_equal ["Only a completed class can be reopened."], archived.errors[:base]
    assert_not active.restore!
    assert_not completed.restore!
    assert_equal ["Only an archived class can be restored."], completed.errors[:base]
    assert completed.reload.completed?
    assert archived.reload.archived?
  end

  test "a stale copy of a class cannot change a status another parent already changed" do
    stale = Course.find(courses(:one).id)
    Course.find(stale.id).complete!

    assert_not stale.archive!
    assert courses(:one).reload.completed?
    assert_not courses(:one).archived?
  end

  test "a class cannot be both completed and archived" do
    course = courses(:one)
    course.completed_at = Time.current
    course.archived_at = Time.current

    assert_not course.valid?
    assert_equal ["A class can't be both completed and archived."], course.errors[:base]
  end

  test "editing a completed or archived class keeps its status and date" do
    completed = courses(:completed)
    archived = courses(:archived)

    assert_no_changes -> { [completed.reload.completed_at, archived.reload.archived_at] } do
      completed.update!(name: "Renamed")
      archived.update!(subject: "Math")
    end
  end

  test "classes can be filtered by learner" do
    assert_equal [courses(:shared)], Course.taken_by(learners(:one)).to_a
    assert_equal [courses(:completed), courses(:shared)].sort_by(&:id), Course.taken_by(learners(:two)).sort_by(&:id)
  end

  test "classes can be filtered by subject ignoring case" do
    assert_equal [courses(:one), courses(:completed)].sort_by(&:id), accounts(:company).courses.with_subject("math").sort_by(&:id)
    assert_empty accounts(:company).courses.with_subject("Latin")
  end

  test "subject filter options include every status once per spelling group, most common spelling first" do
    Course.create!(account: @family, name: "A", subject: "Co-op")
    Course.create!(account: @family, name: "B", subject: "Co-op").archive!
    Course.create!(account: @family, name: "C", subject: "Zoology").complete!
    Course.create!(account: @family, name: "D")
    Course.create!(account: @other_family, name: "Other", subject: "Elsewhere")

    assert_equal ["Co-op", "Zoology"], Course.subject_filter_options_for(@family)
  end

  test "subject filter options keep the most common spelling and the oldest on a tie" do
    Course.insert_all([
      {account_id: @family.id, name: "A", subject: "latin", created_at: 3.days.ago, updated_at: 3.days.ago},
      {account_id: @family.id, name: "B", subject: "Latin", created_at: 2.days.ago, updated_at: 2.days.ago},
      {account_id: @family.id, name: "C", subject: "Latin", created_at: 1.day.ago, updated_at: 1.day.ago},
      {account_id: @family.id, name: "D", subject: "Logic", created_at: 3.days.ago, updated_at: 3.days.ago},
      {account_id: @family.id, name: "E", subject: "LOGIC", created_at: 2.days.ago, updated_at: 2.days.ago},
      {account_id: @family.id, name: "F", subject: "logic", created_at: 1.day.ago, updated_at: 1.day.ago}
    ])

    assert_equal ["Latin", "Logic"], Course.subject_filter_options_for(@family)
  end
end
