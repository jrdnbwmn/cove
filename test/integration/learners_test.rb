require "test_helper"

class LearnersTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @maya = learners(:one)
    @other_family_learner = Learner.create!(account: accounts(:one), name: "Outsider")
  end

  # The Free fixture family starts at its 2-learner limit; archiving Theo opens a slot.
  def open_learner_slot
    learners(:two).archive!
  end

  test "a parent cannot add a learner past the family limit and keeps what they typed" do
    sign_in users(:one)

    assert_no_difference -> { Learner.count } do
      post learners_path, params: {learner: {name: "Nora", grade_level: "5th"}}
    end

    assert_response :unprocessable_content
    assert_match "Free includes 2 learners. Upgrade to Premium to add more.", response.body
    assert_select "input[name='learner[name]'][value='Nora']"
    assert_select "input[name='learner[grade_level]'][value='5th']"
  end

  test "a parent can still edit and archive a selected learner while over the family limit" do
    sign_in users(:one)
    Learner.new(account: @family, name: "Extra", color: "rose").save!(validate: false)
    @maya.update!(kept_on_free: true)

    patch learner_path(@maya), params: {learner: {grade_level: "4th"}}
    assert_redirected_to learners_path
    assert_equal "4th", @maya.reload.grade_level

    post learner_archive_path(@maya)
    assert_redirected_to learners_path
    assert @maya.reload.archived?
  end

  test "guests are sent to sign in" do
    get new_learner_path
    assert_redirected_to new_user_session_path

    post learners_path, params: {learner: {name: "Maya"}}
    assert_redirected_to new_user_session_path
  end

  test "a parent can open the add form inside the modal frame" do
    sign_in users(:one)

    get new_learner_path

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "input[name='learner[name]']"
    assert_select "span.learner-color[data-learner-color='sage']"
    assert_select "span.learner-color[style]", count: 0
  end

  test "a parent can add a learner with only a name and gets a color automatically" do
    open_learner_slot
    sign_in users(:one)

    assert_difference -> { @family.learners.count }, 1 do
      post learners_path, params: {learner: {name: "  Nora  "}}
    end

    learner = @family.learners.find_by!(name: "Nora")
    assert_includes Learner::COLORS, learner.color
    assert_nil learner.grade_level
    assert_redirected_to learners_path
    assert_equal "Nora added.", flash[:notice]
  end

  test "a parent can add a learner with a grade level and color" do
    open_learner_slot
    sign_in users(:one)

    post learners_path, params: {learner: {name: "Nora", grade_level: "5th", color: "slate"}}

    learner = @family.learners.find_by!(name: "Nora")
    assert_equal "5th", learner.grade_level
    assert_equal "slate", learner.color
  end

  test "the other parent in the family can also add and edit learners" do
    open_learner_slot
    sign_in users(:two)

    post learners_path, params: {learner: {name: "Nora"}}
    assert_redirected_to learners_path

    patch learner_path(@maya), params: {learner: {grade_level: "4th"}}
    assert_redirected_to learners_path
    assert_equal "4th", @maya.reload.grade_level
  end

  test "learner params cannot reassign the family" do
    open_learner_slot
    sign_in users(:one)

    post learners_path, params: {learner: {name: "Nora", account_id: accounts(:one).id, archived_at: Time.current}}

    learner = Learner.find_by!(name: "Nora")
    assert_equal @family, learner.account
    assert_nil learner.archived_at
  end

  test "adding a learner with a blank name shows the error and keeps typed values" do
    sign_in users(:one)

    assert_no_difference -> { Learner.count } do
      post learners_path, params: {learner: {name: " ", grade_level: "5th", color: "slate"}}
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "Enter a name to continue.", response.body
    assert_select "input[name='learner[grade_level]'][value='5th']"
  end

  test "adding a duplicate name is refused ignoring case and keeps typed values" do
    sign_in users(:one)

    assert_no_difference -> { Learner.count } do
      post learners_path, params: {learner: {name: " MAYA ", grade_level: "7th"}}
    end

    assert_response :unprocessable_content
    assert_match "You already have a learner named MAYA.", response.body
    assert_select "input[name='learner[grade_level]'][value='7th']"
  end

  test "adding a name that matches an archived learner explains how to restore them" do
    sign_in users(:one)

    post learners_path, params: {learner: {name: "Iris"}}

    assert_response :unprocessable_content
    assert_match "archived learner named Iris", response.body
  end

  test "a duplicate created by the other parent at the same moment is shown as a duplicate" do
    open_learner_slot
    sign_in users(:one)

    with_friendly_uniqueness_check_disabled do
      assert_no_difference -> { Learner.count } do
        post learners_path, params: {learner: {name: "maya", grade_level: "7th"}}
      end
    end

    assert_response :unprocessable_content
    assert_match "You already have a learner named maya.", response.body
    assert_select "input[name='learner[grade_level]'][value='7th']"
  end

  test "a parent can open the edit form for an active learner" do
    sign_in users(:one)

    get edit_learner_path(@maya)

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "input[name='learner[name]'][value='Maya']"
  end

  test "a parent can edit a learner's name, grade and color" do
    sign_in users(:one)

    patch learner_path(@maya), params: {learner: {name: "Maya R", grade_level: "", color: "rose"}}

    assert_redirected_to learners_path
    assert_equal "Saved.", flash[:notice]
    @maya.reload
    assert_equal "Maya R", @maya.name
    assert_nil @maya.grade_level
    assert_equal "rose", @maya.color
  end

  test "a learner can be saved with their own name unchanged" do
    sign_in users(:one)

    patch learner_path(@maya), params: {learner: {name: "maya", grade_level: "8th"}}

    assert_redirected_to learners_path
    assert_equal "maya", @maya.reload.name
  end

  test "editing with an invalid value shows the error and keeps typed values" do
    sign_in users(:one)

    patch learner_path(@maya), params: {learner: {name: "Theo", grade_level: "9th"}}

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "You already have a learner named Theo.", response.body
    assert_select "input[name='learner[grade_level]'][value='9th']"
    assert_equal "Maya", @maya.reload.name
  end

  test "an edit that loses a duplicate race is shown as a duplicate" do
    sign_in users(:one)

    with_friendly_uniqueness_check_disabled do
      patch learner_path(@maya), params: {learner: {name: "theo"}}
    end

    assert_response :unprocessable_content
    assert_match "You already have a learner named theo.", response.body
    assert_equal "Maya", @maya.reload.name
  end

  test "archived learners cannot be edited" do
    sign_in users(:one)

    get edit_learner_path(learners(:archived))
    assert_redirected_to learners_path

    patch learner_path(learners(:archived)), params: {learner: {name: "Changed"}}
    assert_redirected_to learners_path
    assert_equal "Iris", learners(:archived).reload.name
  end

  test "a parent cannot open or directly save a read-only learner's edit form" do
    learner = learners(:read_only)
    sign_in users(:downgraded)

    get edit_learner_path(learner)
    assert_redirected_to learners_path
    assert_equal "Casey can't be edited on Free. You can still archive or delete this learner.", flash[:alert]

    patch learner_path(learner), params: {learner: {name: "Changed"}}
    assert_redirected_to learners_path
    assert_equal "Casey", learner.reload.name
  end

  test "a selected learner and all learners after re-subscribing can be edited" do
    sign_in users(:downgraded)

    get edit_learner_path(learners(:kept))
    assert_response :success

    accounts(:downgraded).update!(complimentary_premium: true, complimentary_premium_note: "Temporary Premium")
    get edit_learner_path(learners(:read_only))
    assert_response :success
  end

  test "another family's learner cannot be edited or updated" do
    sign_in users(:one)

    get edit_learner_path(@other_family_learner)
    assert_response :not_found

    # The 404 aborts the request before Warden persists the session, so sign in again.
    sign_in users(:one)
    patch learner_path(@other_family_learner), params: {learner: {name: "Taken over"}}
    assert_response :not_found
    assert_equal "Outsider", @other_family_learner.reload.name
  end

  test "the edit form offers archive and delete for an active learner" do
    sign_in users(:one)

    get edit_learner_path(@maya)

    assert_select "form[action='#{learner_archive_path(@maya)}'][method='post'] button", text: /\AArchive/
    assert_select "a[href='#{delete_learner_path(@maya)}']", text: "Delete"
    assert_select "[data-ui-modal-turbo-frame-src-value='#{delete_learner_path(@maya)}']", count: 0
  end

  test "a parent sees a delete confirmation inside the modal frame" do
    sign_in users(:one)

    get delete_learner_path(@maya)

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "Delete Maya?", response.body
    assert_match "permanently removes Maya", response.body
    assert_select "form[action='#{learner_path(@maya)}'] input[name='_method'][value='delete']"
    assert_select "a[href='#{edit_learner_path(@maya)}']", text: "Cancel"
  end

  test "the delete confirmation opened from the learner list cancels by closing the modal" do
    sign_in users(:one)

    get delete_learner_path(@maya, from: "list")

    assert_response :success
    assert_select "a[href='#{edit_learner_path(@maya)}']", count: 0
    assert_select "button[data-action='click->ui-modal#performClose:prevent']", text: "Cancel"
    assert_select "form[action='#{learner_path(@maya)}'] input[name='_method'][value='delete']"
  end

  test "a parent can view a read-only learner and return there from delete confirmation" do
    sign_in users(:downgraded)

    get learner_path(learners(:read_only))
    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "p", text: /Casey can't be edited on Free/

    get delete_learner_path(learners(:read_only))
    assert_select "a[href='#{learner_path(learners(:read_only))}']", text: "Cancel"
  end

  test "viewing an editable learner sends the parent to the edit form instead" do
    sign_in users(:downgraded)

    get learner_path(learners(:kept))
    assert_redirected_to edit_learner_path(learners(:kept))

    sign_in users(:one)
    get learner_path(learners(:one))
    assert_redirected_to edit_learner_path(learners(:one))
  end

  test "guests and other families cannot view a learner" do
    get learner_path(learners(:read_only))
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    get learner_path(learners(:read_only))
    assert_response :not_found
  end

  test "cancelling the confirmation for an archived learner closes the modal" do
    sign_in users(:one)

    get delete_learner_path(learners(:archived))

    assert_response :success
    assert_select "a[href='#{edit_learner_path(learners(:archived))}']", count: 0
    assert_select "button[data-action='click->ui-modal#performClose:prevent']", text: "Cancel"
  end

  test "a parent can permanently delete a learner" do
    sign_in users(:one)

    assert_difference -> { @family.learners.count }, -1 do
      delete learner_path(@maya)
    end

    assert_redirected_to learners_path
    assert_equal "Maya deleted.", flash[:notice]
    assert_not Learner.exists?(@maya.id)
  end

  test "the other parent can delete a learner and an archived learner can be deleted" do
    sign_in users(:two)

    delete learner_path(learners(:archived))

    assert_redirected_to learners_path
    assert_not Learner.exists?(learners(:archived).id)
  end

  test "another family's learner cannot be deleted or confirmed for deletion" do
    sign_in users(:one)

    get delete_learner_path(@other_family_learner)
    assert_response :not_found

    sign_in users(:one)
    assert_no_difference -> { Learner.count } do
      delete learner_path(@other_family_learner)
    end
    assert_response :not_found
  end

  private

  # AIDEV-NOTE: Simulates two parents saving the same name at once: with the friendly
  # model check skipped, only the unique index stands between the write and a duplicate.
  def with_friendly_uniqueness_check_disabled
    Learner.class_eval do
      alias_method :original_name_unique_within_account, :name_unique_within_account
      define_method(:name_unique_within_account) {}
    end
    yield
  ensure
    Learner.class_eval do
      alias_method :name_unique_within_account, :original_name_unique_within_account
      remove_method :original_name_unique_within_account
    end
  end
end
