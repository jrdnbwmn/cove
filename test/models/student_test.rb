require "test_helper"

class StudentTest < ActiveSupport::TestCase
  # AIDEV-NOTE: Database-level assertions use a bare record class so they hold
  # even if model validations change; the model's own behavior is tested below.
  class StudentRow < ApplicationRecord
    self.table_name = "students"
  end

  def row_attributes(overrides = {})
    {account_id: accounts(:company).id, name: "Zed", color: "teal"}.merge(overrides)
  end

  test "database requires a family, name and color" do
    %i[account_id name color].each do |column|
      assert_raises(ActiveRecord::NotNullViolation, "#{column} should be required") do
        StudentRow.new(row_attributes(column => nil)).save!(validate: false)
      end
    end
  end

  test "database rejects a student for a family that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      StudentRow.create!(row_attributes(account_id: 0))
    end
  end

  test "database rejects duplicate names within one family regardless of case" do
    StudentRow.create!(row_attributes(name: "Zed"))

    assert_raises(ActiveRecord::RecordNotUnique) do
      StudentRow.create!(row_attributes(name: "ZED"))
    end
  end

  test "database allows the same name in different families" do
    StudentRow.create!(row_attributes(name: "Zed"))

    assert_nothing_raised do
      StudentRow.create!(row_attributes(account_id: accounts(:one).id, name: "zed"))
    end
  end
end

class StudentBehaviorTest < ActiveSupport::TestCase
  # AIDEV-NOTE: General student behavior runs on a Premium family so tests that
  # create many students aren't stopped by the Free limit; limit tests use Free families.
  setup do
    @family = accounts(:subscribed)
    @other_family = accounts(:one)
    Student.where(account: @family).delete_all
  end

  def build_student(attrs = {})
    Student.new({account: @family, name: "Maya"}.merge(attrs))
  end

  test "name and grade level are stripped and a blank grade level is removed" do
    student = Student.create!(account: @family, name: "  Maya  ", grade_level: "  3rd ")
    assert_equal "Maya", student.name
    assert_equal "3rd", student.grade_level

    student.update!(grade_level: "   ")
    assert_nil student.grade_level
  end

  test "a student needs a name" do
    student = build_student(name: "   ")
    assert_not student.valid?
    assert_equal ["Enter a name to continue."], student.errors[:name]
  end

  test "name and grade level can each be 50 characters but not more" do
    assert build_student(name: "a" * 50, grade_level: "b" * 50).valid?

    student = build_student(name: "a" * 51, grade_level: "b" * 51)
    assert_not student.valid?
    assert student.errors[:name].any?
    assert student.errors[:grade_level].any?
  end

  test "grade level is optional" do
    assert build_student(grade_level: nil).valid?
  end

  test "a family cannot have two active students with the same name ignoring case and spaces" do
    Student.create!(account: @family, name: "Maya")

    duplicate = build_student(name: "  mAYa ")
    assert_not duplicate.valid?
    assert_equal ["You already have a student named mAYa."], duplicate.errors[:name]
  end

  test "the duplicate message differs when the existing student is archived" do
    Student.create!(account: @family, name: "Maya", archived_at: Time.current)

    duplicate = build_student(name: "Maya")
    assert_not duplicate.valid?
    assert_equal [
      "You already have an archived student named Maya. Restore them from archived students, or use a different name."
    ], duplicate.errors[:name]
  end

  test "two families can each have a student with the same name" do
    Student.create!(account: @family, name: "Maya")
    assert Student.new(account: @other_family, name: "Maya").valid?
  end

  test "a student can keep their own name when updated" do
    student = Student.create!(account: @family, name: "Maya")
    assert student.update(grade_level: "4th")
  end

  test "color must be in the palette" do
    student = build_student(color: "neon")
    assert_not student.valid?
    assert student.errors[:color].any?
  end

  test "every palette color is accepted" do
    Student::COLORS.each { |color| assert build_student(color: color).valid?, color }
  end

  test "a new student gets a palette color automatically" do
    student = Student.create!(account: @family, name: "Maya")
    assert_includes Student::COLORS, student.color
  end

  test "a second student gets a different color than the first" do
    first = Student.create!(account: @family, name: "Maya")
    second = Student.create!(account: @family, name: "Theo")
    assert_not_equal first.color, second.color
  end

  test "a provided color is kept" do
    student = Student.create!(account: @family, name: "Maya", color: "slate")
    assert_equal "slate", student.color
  end

  test "next color is the first palette color for a family with no students" do
    assert_equal Student::COLORS.first, Student.next_color_for(@family)
  end

  test "next color is the least used and ties go to the earliest in the palette" do
    Student::COLORS.each_with_index { |color, i| Student.create!(account: @family, name: "S#{i}", color: color) }
    assert_equal Student::COLORS.first, Student.next_color_for(@family)

    Student.create!(account: @family, name: "Extra", color: Student::COLORS.first)
    assert_equal Student::COLORS.second, Student.next_color_for(@family)
  end

  test "archived students do not count toward color usage" do
    Student::COLORS.each_with_index do |color, i|
      Student.create!(account: @family, name: "S#{i}", color: color, archived_at: (Time.current if color == "rose"))
    end

    assert_equal "rose", Student.next_color_for(@family)
  end

  test "other families do not affect color allocation" do
    Student.create!(account: @other_family, name: "Maya", color: "sage")
    assert_equal "sage", Student.next_color_for(@family)
  end

  test "active and archived scopes split students by archived state" do
    active = Student.create!(account: @family, name: "Maya")
    archived = Student.create!(account: @family, name: "Theo", archived_at: Time.current)

    assert_equal [active], @family.students.active.to_a
    assert_equal [archived], @family.students.archived.to_a
  end

  test "listing is in creation order" do
    later = Student.create!(account: @family, name: "Later", created_at: 1.day.ago)
    earlier = Student.create!(account: @family, name: "Earlier", created_at: 2.days.ago)

    assert_equal [earlier, later], @family.students.ordered.to_a
  end

  test "archiving is idempotent and hides the student from the active list" do
    student = Student.create!(account: @family, name: "Maya")
    student.archive!
    stamp = student.archived_at

    assert student.archived?
    student.archive!
    assert_equal stamp, student.reload.archived_at
  end

  test "restoring is idempotent and keeps the color" do
    student = Student.create!(account: @family, name: "Maya", color: "ochre", archived_at: Time.current)
    student.restore!

    assert_nil student.reload.archived_at
    assert_equal "ochre", student.color
    assert_nothing_raised { student.restore! }
  end
end

class StudentLimitTest < ActiveSupport::TestCase
  setup do
    @free = accounts(:one)
    Student.where(account: @free).delete_all
  end

  test "a Free family can add a second student but not a third" do
    Student.create!(account: @free, name: "Maya")
    assert Student.new(account: @free, name: "Theo").save

    third = Student.new(account: @free, name: "Iris")
    assert_not third.save
    assert_equal ["Free includes 2 students. Upgrade to Premium to add more."], third.errors[:base]
  end

  test "a Premium family is refused past its limit with Premium copy" do
    family = accounts(:subscribed)
    family.update!(student_limit: 3)
    Student.where(account: family).delete_all
    3.times { |i| Student.create!(account: family, name: "S#{i}") }

    student = Student.new(account: family, name: "Extra")
    assert_not student.save
    assert_equal ["Premium includes 3 students. Contact us to add more."], student.errors[:base]
  end

  test "a complimentary Premium family sees the Premium copy" do
    family = accounts(:complimentary)
    Student.where(account: family).delete_all
    10.times { |i| Student.create!(account: family, name: "S#{i}") }

    student = Student.new(account: family, name: "Extra")
    assert_not student.save
    assert_equal ["Premium includes 10 students. Contact us to add more."], student.errors[:base]
  end

  test "a student cannot be restored while the family is at its limit" do
    Student.create!(account: @free, name: "Maya")
    Student.create!(account: @free, name: "Theo")
    archived = Student.create!(account: @free, name: "Iris", archived_at: Time.current)

    assert_raises(ActiveRecord::RecordInvalid) { archived.restore! }
    assert archived.reload.archived?
  end

  test "a student can be restored once a slot opens" do
    maya = Student.create!(account: @free, name: "Maya")
    Student.create!(account: @free, name: "Theo")
    archived = Student.create!(account: @free, name: "Iris", archived_at: Time.current)

    maya.archive!
    archived.restore!

    assert_not archived.reload.archived?
  end

  test "an archived student can be created at the limit" do
    Student.create!(account: @free, name: "Maya")
    Student.create!(account: @free, name: "Theo")

    assert Student.new(account: @free, name: "Iris", archived_at: Time.current).save
  end

  test "editing and archiving still work when a family is over its limit" do
    students = %w[Maya Theo Iris].map { |name| Student.new(account: @free, name: name, color: "sage").tap { |s| s.save!(validate: false) } }

    assert students.first.update(grade_level: "4th")
    assert_nothing_raised { students.first.archive! }
    assert students.first.reload.archived?
  end

  test "a family's limit does not depend on other families' students" do
    Student.create!(account: accounts(:two), name: "Maya")
    Student.create!(account: accounts(:two), name: "Theo")

    assert Student.new(account: @free, name: "Maya").save
  end
end

class StudentLimitConcurrencyTest < ActiveSupport::TestCase
  # AIDEV-NOTE: Needs real commits across separate connections, so it can't run
  # inside the usual per-test transaction; teardown removes what it created.
  self.use_transactional_tests = false

  setup do
    @family_id = accounts(:one).id
    Student.where(account_id: @family_id).delete_all
    Student.create!(account_id: @family_id, name: "Maya")
  end

  teardown do
    Student.where(account_id: @family_id).delete_all
  end

  test "two parents saving the last free slot at once only get one student" do
    start = Queue.new
    results = %w[Theo Iris].map do |name|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          Student.new(account_id: @family_id, name: name).save
        end
      end
    end
    2.times { start << true }

    assert_equal [false, true], results.map(&:value).sort_by { |saved| saved ? 1 : 0 }
    assert_equal 2, Student.active.where(account_id: @family_id).count
  end
end
