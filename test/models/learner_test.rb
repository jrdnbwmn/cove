require "test_helper"

class LearnerTest < ActiveSupport::TestCase
  # AIDEV-NOTE: Database-level assertions use a bare record class so they hold
  # even if model validations change; the model's own behavior is tested below.
  class LearnerRow < ApplicationRecord
    self.table_name = "learners"
  end

  def row_attributes(overrides = {})
    {account_id: accounts(:company).id, name: "Zed", color: "teal"}.merge(overrides)
  end

  test "database requires a family, name and color" do
    %i[account_id name color].each do |column|
      assert_raises(ActiveRecord::NotNullViolation, "#{column} should be required") do
        LearnerRow.new(row_attributes(column => nil)).save!(validate: false)
      end
    end
  end

  test "database defaults kept on free to false and requires a value" do
    learner = LearnerRow.create!(row_attributes)
    assert_not learner.kept_on_free?

    assert_raises(ActiveRecord::NotNullViolation) do
      LearnerRow.new(row_attributes(name: "Kept", kept_on_free: nil)).save!(validate: false)
    end
  end

  test "database rejects a learner for a family that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      LearnerRow.create!(row_attributes(account_id: 0))
    end
  end

  test "database rejects duplicate names within one family regardless of case" do
    LearnerRow.create!(row_attributes(name: "Zed"))

    assert_raises(ActiveRecord::RecordNotUnique) do
      LearnerRow.create!(row_attributes(name: "ZED"))
    end
  end

  test "database allows the same name in different families" do
    LearnerRow.create!(row_attributes(name: "Zed"))

    assert_nothing_raised do
      LearnerRow.create!(row_attributes(account_id: accounts(:one).id, name: "zed"))
    end
  end
end

class LearnerBehaviorTest < ActiveSupport::TestCase
  # AIDEV-NOTE: General learner behavior runs on a Premium family so tests that
  # create many learners aren't stopped by the Free limit; limit tests use Free families.
  setup do
    @family = accounts(:subscribed)
    @other_family = accounts(:one)
    Learner.where(account: @family).delete_all
  end

  def build_learner(attrs = {})
    Learner.new({account: @family, name: "Maya"}.merge(attrs))
  end

  test "name and grade level are stripped and a blank grade level is removed" do
    learner = Learner.create!(account: @family, name: "  Maya  ", grade_level: "  3rd ")
    assert_equal "Maya", learner.name
    assert_equal "3rd", learner.grade_level

    learner.update!(grade_level: "   ")
    assert_nil learner.grade_level
  end

  test "a learner needs a name" do
    learner = build_learner(name: "   ")
    assert_not learner.valid?
    assert_equal ["Enter a name to continue."], learner.errors[:name]
  end

  test "name and grade level can each be 50 characters but not more" do
    assert build_learner(name: "a" * 50, grade_level: "b" * 50).valid?

    learner = build_learner(name: "a" * 51, grade_level: "b" * 51)
    assert_not learner.valid?
    assert learner.errors[:name].any?
    assert learner.errors[:grade_level].any?
  end

  test "grade level is optional" do
    assert build_learner(grade_level: nil).valid?
  end

  test "a family cannot have two active learners with the same name ignoring case and spaces" do
    Learner.create!(account: @family, name: "Maya")

    duplicate = build_learner(name: "  mAYa ")
    assert_not duplicate.valid?
    assert_equal ["You already have a learner named mAYa."], duplicate.errors[:name]
  end

  test "the duplicate message differs when the existing learner is archived" do
    Learner.create!(account: @family, name: "Maya", archived_at: Time.current)

    duplicate = build_learner(name: "Maya")
    assert_not duplicate.valid?
    assert_equal [
      "You already have an archived learner named Maya. Restore them from archived learners, or use a different name."
    ], duplicate.errors[:name]
  end

  test "two families can each have a learner with the same name" do
    Learner.create!(account: @family, name: "Maya")
    assert Learner.new(account: @other_family, name: "Maya").valid?
  end

  test "a learner can keep their own name when updated" do
    learner = Learner.create!(account: @family, name: "Maya")
    assert learner.update(grade_level: "4th")
  end

  test "color must be in the palette" do
    learner = build_learner(color: "neon")
    assert_not learner.valid?
    assert learner.errors[:color].any?
  end

  test "every palette color is accepted" do
    Learner::COLORS.each { |color| assert build_learner(color: color).valid?, color }
  end

  test "a new learner gets a palette color automatically" do
    learner = Learner.create!(account: @family, name: "Maya")
    assert_includes Learner::COLORS, learner.color
  end

  test "a second learner gets a different color than the first" do
    first = Learner.create!(account: @family, name: "Maya")
    second = Learner.create!(account: @family, name: "Theo")
    assert_not_equal first.color, second.color
  end

  test "a provided color is kept" do
    learner = Learner.create!(account: @family, name: "Maya", color: "slate")
    assert_equal "slate", learner.color
  end

  test "next color is the first palette color for a family with no learners" do
    assert_equal Learner::COLORS.first, Learner.next_color_for(@family)
  end

  test "next color is the least used and ties go to the earliest in the palette" do
    Learner::COLORS.each_with_index { |color, i| Learner.create!(account: @family, name: "S#{i}", color: color) }
    assert_equal Learner::COLORS.first, Learner.next_color_for(@family)

    Learner.create!(account: @family, name: "Extra", color: Learner::COLORS.first)
    assert_equal Learner::COLORS.second, Learner.next_color_for(@family)
  end

  test "archived learners do not count toward color usage" do
    Learner::COLORS.each_with_index do |color, i|
      Learner.create!(account: @family, name: "S#{i}", color: color, archived_at: (Time.current if color == "rose"))
    end

    assert_equal "rose", Learner.next_color_for(@family)
  end

  test "other families do not affect color allocation" do
    Learner.create!(account: @other_family, name: "Maya", color: "sage")
    assert_equal "sage", Learner.next_color_for(@family)
  end

  test "active and archived scopes split learners by archived state" do
    active = Learner.create!(account: @family, name: "Maya")
    archived = Learner.create!(account: @family, name: "Theo", archived_at: Time.current)

    assert_equal [active], @family.learners.active.to_a
    assert_equal [archived], @family.learners.archived.to_a
  end

  test "listing is in creation order" do
    later = Learner.create!(account: @family, name: "Later", created_at: 1.day.ago)
    earlier = Learner.create!(account: @family, name: "Earlier", created_at: 2.days.ago)

    assert_equal [earlier, later], @family.learners.ordered.to_a
  end

  test "archiving is idempotent and hides the learner from the active list" do
    learner = Learner.create!(account: @family, name: "Maya")
    learner.archive!
    stamp = learner.archived_at

    assert learner.archived?
    learner.archive!
    assert_equal stamp, learner.reload.archived_at
  end

  test "archiving clears a selected learner while leaving the other selected learner intact" do
    kept = learners(:kept)
    other_kept = learners(:kept_two)

    kept.archive!

    assert_not kept.reload.kept_on_free?
    assert_predicate other_kept.reload, :kept_on_free?
  end

  test "archiving an already archived selected learner clears its selection" do
    learner = learners(:kept)
    learner.update!(archived_at: Time.current)

    learner.archive!

    assert_not learner.reload.kept_on_free?
  end

  test "restoring is idempotent and keeps the color" do
    learner = Learner.create!(account: @family, name: "Maya", color: "ochre", archived_at: Time.current)
    learner.restore!

    assert_nil learner.reload.archived_at
    assert_equal "ochre", learner.color
    assert_nothing_raised { learner.restore! }
  end
end

class LearnerEnrollmentTest < ActiveSupport::TestCase
  test "deleting a learner removes their class enrollments" do
    learner = learners(:one)
    enrollment = Enrollment.create!(course: courses(:one), learner: learner)

    assert_difference "Enrollment.count", -learner.enrollments.count do
      learner.destroy!
    end

    assert_not Enrollment.exists?(enrollment.id)
  end

  test "a learner can list their classes" do
    learner = learners(:one)
    course = courses(:one)
    Enrollment.create!(course: course, learner: learner)

    assert_includes learner.courses, course
  end
end

class LearnerEditabilityTest < ActiveSupport::TestCase
  setup do
    @family = accounts(:downgraded)
    @kept = learners(:kept)
    @read_only = learners(:read_only)
  end

  test "a selected learner is editable while an unselected learner is read-only after a Free downgrade" do
    assert_predicate @kept, :editable?
    assert_not_predicate @read_only, :editable?
  end

  test "reaching two active learners makes both selected and unselected learners editable" do
    learners(:read_only).archive!
    learners(:read_only_two).archive!
    learners(:read_only_three).archive!

    assert_not @family.reload.over_free_learner_limit?
    assert_predicate @kept, :editable?
    assert_predicate @read_only, :editable?
  end

  test "re-subscribing makes all learners editable while retaining the later-downgrade selection" do
    @family.update!(complimentary_premium: true, complimentary_premium_note: "Temporary Premium")

    assert_predicate @kept, :editable?
    assert_predicate @read_only, :editable?
    assert_predicate @kept.reload, :kept_on_free?
  end
end

class LearnerLimitTest < ActiveSupport::TestCase
  setup do
    @free = accounts(:one)
    Learner.where(account: @free).delete_all
  end

  test "a Free family can add a second learner but not a third" do
    Learner.create!(account: @free, name: "Maya")
    assert Learner.new(account: @free, name: "Theo").save

    third = Learner.new(account: @free, name: "Iris")
    assert_not third.save
    assert_equal ["Free includes 2 learners. Upgrade to Premium to add more."], third.errors[:base]
  end

  test "a Premium family is refused past its limit with Premium copy" do
    family = accounts(:subscribed)
    family.update!(learner_limit: 3)
    Learner.where(account: family).delete_all
    3.times { |i| Learner.create!(account: family, name: "S#{i}") }

    learner = Learner.new(account: family, name: "Extra")
    assert_not learner.save
    assert_equal ["Premium includes 3 learners. Contact us to add more."], learner.errors[:base]
  end

  test "a complimentary Premium family sees the Premium copy" do
    family = accounts(:complimentary)
    Learner.where(account: family).delete_all
    10.times { |i| Learner.create!(account: family, name: "S#{i}") }

    learner = Learner.new(account: family, name: "Extra")
    assert_not learner.save
    assert_equal ["Premium includes 10 learners. Contact us to add more."], learner.errors[:base]
  end

  test "a learner cannot be restored while the family is at its limit" do
    Learner.create!(account: @free, name: "Maya")
    Learner.create!(account: @free, name: "Theo")
    archived = Learner.create!(account: @free, name: "Iris", archived_at: Time.current)

    assert_raises(ActiveRecord::RecordInvalid) { archived.restore! }
    assert archived.reload.archived?
  end

  test "a learner can be restored once a slot opens" do
    maya = Learner.create!(account: @free, name: "Maya")
    Learner.create!(account: @free, name: "Theo")
    archived = Learner.create!(account: @free, name: "Iris", archived_at: Time.current)

    maya.archive!
    archived.restore!

    assert_not archived.reload.archived?
  end

  test "an archived learner can be created at the limit" do
    Learner.create!(account: @free, name: "Maya")
    Learner.create!(account: @free, name: "Theo")

    assert Learner.new(account: @free, name: "Iris", archived_at: Time.current).save
  end

  test "editing and archiving still work when a family is over its limit" do
    learners = %w[Maya Theo Iris].map { |name| Learner.new(account: @free, name: name, color: "sage").tap { |s| s.save!(validate: false) } }

    assert learners.first.update(grade_level: "4th")
    assert_nothing_raised { learners.first.archive! }
    assert learners.first.reload.archived?
  end

  test "a family's limit does not depend on other families' learners" do
    Learner.create!(account: accounts(:two), name: "Maya")
    Learner.create!(account: accounts(:two), name: "Theo")

    assert Learner.new(account: @free, name: "Maya").save
  end
end

class LearnerLimitConcurrencyTest < ActiveSupport::TestCase
  # AIDEV-NOTE: Needs real commits across separate connections, so it can't run
  # inside the usual per-test transaction; teardown removes what it created.
  self.use_transactional_tests = false

  setup do
    @family_id = accounts(:one).id
    Learner.where(account_id: @family_id).delete_all
    Learner.create!(account_id: @family_id, name: "Maya")
  end

  teardown do
    Learner.where(account_id: @family_id).delete_all
  end

  test "two parents saving the last free slot at once only get one learner" do
    start = Queue.new
    results = %w[Theo Iris].map do |name|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          Learner.new(account_id: @family_id, name: name).save
        end
      end
    end
    2.times { start << true }

    assert_equal [false, true], results.map(&:value).sort_by { |saved| saved ? 1 : 0 }
    assert_equal 2, Learner.active.where(account_id: @family_id).count
  end
end
