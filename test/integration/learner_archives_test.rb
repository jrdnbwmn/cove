require "test_helper"

class LearnerArchivesTest < ActionDispatch::IntegrationTest
  setup do
    @maya = learners(:one)
    @archived = learners(:archived)
    @other_family_learner = Learner.create!(account: accounts(:one), name: "Outsider")
  end

  test "guests are sent to sign in" do
    post learner_archive_path(@maya)
    assert_redirected_to new_user_session_path

    delete learner_archive_path(@archived)
    assert_redirected_to new_user_session_path
  end

  test "a parent can archive a learner" do
    sign_in users(:one)

    post learner_archive_path(@maya)

    assert_redirected_to learners_path
    assert_equal "Maya archived.", flash[:notice]
    assert @maya.reload.archived?
  end

  test "the other parent can archive and restore too" do
    sign_in users(:two)

    post learner_archive_path(@maya)
    assert @maya.reload.archived?

    delete learner_archive_path(@maya)
    assert_not @maya.reload.archived?
  end

  test "archiving an already archived learner changes nothing and still confirms" do
    sign_in users(:one)
    stamp = @archived.archived_at

    post learner_archive_path(@archived)

    assert_redirected_to learners_path
    assert_equal "Iris archived.", flash[:notice]
    assert_equal stamp.to_i, @archived.reload.archived_at.to_i
  end

  test "archiving a selected learner clears only that learner's selection" do
    sign_in users(:downgraded)

    post learner_archive_path(learners(:kept))

    assert_redirected_to learners_path
    assert learners(:kept).reload.archived?
    assert_not learners(:kept).kept_on_free?
    assert_predicate learners(:kept_two).reload, :kept_on_free?
  end

  test "archiving an already archived selected learner clears its selection" do
    @archived.update!(kept_on_free: true)
    sign_in users(:one)

    post learner_archive_path(@archived)

    assert_redirected_to learners_path
    assert_not @archived.reload.kept_on_free?
  end

  test "a parent can restore an archived learner and the color is unchanged" do
    sign_in users(:one)
    learners(:two).archive!
    color = @archived.color

    delete learner_archive_path(@archived)

    assert_redirected_to learners_path
    assert_equal "Iris restored.", flash[:notice]
    assert_not @archived.reload.archived?
    assert_equal color, @archived.color
  end

  test "restoring past the family limit is refused and the learner stays archived" do
    sign_in users(:one)

    delete learner_archive_path(@archived)

    assert_redirected_to learners_path
    assert_response :see_other
    assert_equal "Free includes 2 learners. Upgrade to Premium to add more.", flash[:alert]
    assert @archived.reload.archived?
  end

  test "restoring an active learner changes nothing and still confirms" do
    sign_in users(:one)

    delete learner_archive_path(@maya)

    assert_redirected_to learners_path
    assert_equal "Maya restored.", flash[:notice]
    assert_not @maya.reload.archived?
  end

  test "another family's learner cannot be archived or restored" do
    sign_in users(:one)

    post learner_archive_path(@other_family_learner)
    assert_response :not_found
    assert_not @other_family_learner.reload.archived?

    sign_in users(:one)
    @other_family_learner.update!(archived_at: Time.current)
    delete learner_archive_path(@other_family_learner)
    assert_response :not_found
    assert @other_family_learner.reload.archived?
  end
end
