require "test_helper"

class LearnersTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @maya = learners(:one)
    @other_family_learner = Learner.create!(account: accounts(:one), name: "Outsider")
  end

  # Archive a learner for tests exercising creation with an archived sibling.
  def open_learner_slot
    learners(:two).archive!
  end

  test "guests cannot view learner pages" do
    get learner_path(@maya)
    assert_redirected_to new_user_session_path
  end

  [:one, :two].each do |parent|
    test "#{parent} can view active and archived learner pages on Free with Learners selected" do
      sign_in users(parent)
      assert @family.free?
      [@maya, learners(:archived)].each do |learner|
        get learner_path(learner)
        assert_response :success
        assert_select "h1", text: learner.name
        assert_select "a[href='#{learners_path}']", text: "← Learners"
        assert_select "a[href='#{learners_path}'][aria-current='page']"
        assert_select ".learner-color[data-learner-color='#{learner.color}']"
        assert_select "p", text: learner.grade_level
      end
    end
  end

  test "missing and other-family learner pages return not found" do
    [@other_family_learner.id, 0].each do |id|
      sign_in users(:one)
      get learner_path(id)
      assert_response :not_found
    end
  end

  test "tampered grades cannot create or update learners and show an inline error" do
    sign_in users(:one)
    ["3rd", "unknown", "a" * 51].each do |grade|
      assert_no_difference "Learner.count" do
        post learners_path, params: {learner: {name: "Nora", grade_level: grade}}
      end
      assert_response :unprocessable_content
      assert_select "form#learner-form p.text-red-600", text: /./
      original = @maya.attributes
      patch learner_path(@maya), params: {learner: {name: "Changed", grade_level: grade}}
      assert_response :unprocessable_content
      assert_select "form#learner-form p.text-red-600", text: /./
      assert_equal original, @maya.reload.attributes
    end
  end

  test "a parent cannot add a learner past the family limit and keeps what they typed" do
    sign_in users(:one)
    13.times { |i| Learner.create!(account: @family, name: "Learner #{i}") }

    assert_no_difference -> { Learner.count } do
      post learners_path, params: {learner: {name: "Nora", grade_level: "5th grade"}}
    end

    assert_response :unprocessable_content
    assert_match "To add more than 15 learners, send us a quick note and we&#39;ll raise your limit.", response.body
    assert_select "input[name='learner[name]'][value='Nora']"
    assert_select "select[name='learner[grade_level]'] option[selected][value='5th grade']"
  end

  test "a parent can still edit and archive a learner while over the family limit" do
    sign_in users(:one)
    14.times { |i| Learner.new(account: @family, name: "Extra #{i}", color: "rose").save!(validate: false) }

    patch learner_path(@maya), params: {learner: {grade_level: "4th grade"}}
    assert_redirected_to learners_path
    assert_equal "4th grade", @maya.reload.grade_level

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

    post learners_path, params: {learner: {name: "Nora", grade_level: "5th grade", color: "slate"}}

    learner = @family.learners.find_by!(name: "Nora")
    assert_equal "5th grade", learner.grade_level
    assert_equal "slate", learner.color
  end

  test "the other parent in the family can also add and edit learners" do
    open_learner_slot
    sign_in users(:two)

    post learners_path, params: {learner: {name: "Nora"}}
    assert_redirected_to learners_path

    patch learner_path(@maya), params: {learner: {grade_level: "4th grade"}}
    assert_redirected_to learners_path
    assert_equal "4th grade", @maya.reload.grade_level
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
      post learners_path, params: {learner: {name: " ", grade_level: "5th grade", color: "slate"}}
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "Enter a name to continue.", response.body
    assert_select "select[name='learner[grade_level]'] option[selected][value='5th grade']"
  end

  test "adding a duplicate name is refused ignoring case and keeps typed values" do
    sign_in users(:one)

    assert_no_difference -> { Learner.count } do
      post learners_path, params: {learner: {name: " MAYA ", grade_level: "7th grade"}}
    end

    assert_response :unprocessable_content
    assert_match "You already have a learner named MAYA.", response.body
    assert_select "select[name='learner[grade_level]'] option[selected][value='7th grade']"
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
        post learners_path, params: {learner: {name: "maya", grade_level: "7th grade"}}
      end
    end

    assert_response :unprocessable_content
    assert_match "You already have a learner named maya.", response.body
    assert_select "select[name='learner[grade_level]'] option[selected][value='7th grade']"
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

    patch learner_path(@maya), params: {learner: {name: "maya", grade_level: "8th grade"}}

    assert_redirected_to learners_path
    assert_equal "maya", @maya.reload.name
  end

  test "editing with an invalid value shows the error and keeps typed values" do
    sign_in users(:one)

    patch learner_path(@maya), params: {learner: {name: "Theo", grade_level: "9th grade"}}

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "You already have a learner named Theo.", response.body
    assert_select "select[name='learner[grade_level]'] option[selected][value='9th grade']"
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

  test "a Free family above the old limit can edit and save every active learner" do
    sign_in users(:downgraded)
    accounts(:downgraded).learners.active.each do |learner|
      get edit_learner_path(learner)
      assert_response :success
      patch learner_path(learner), params: {learner: {grade_level: "4th grade"}}
      assert_redirected_to learners_path
      assert_equal "4th grade", learner.reload.grade_level
    end
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

  test "stale picker submissions return not found" do
    [["get", "/learners/kept/edit"], ["patch", "/learners/kept"]].each do |method, path|
      sign_in users(:one)
      before = @family.learners.order(:id).map(&:attributes)
      public_send(method, path, params: {learner_ids: [learners(:one).id]})
      assert_response :not_found
      assert_equal before, @family.learners.reload.order(:id).map(&:attributes)
    end
  end

  test "cancelling the confirmation for an archived learner closes the modal" do
    sign_in users(:one)

    get delete_learner_path(learners(:archived))

    assert_response :success
    assert_select "a[href='#{edit_learner_path(learners(:archived))}']", count: 0
    assert_select "button[data-action='click->ui-modal#performClose:prevent']", text: "Cancel"
  end

  [:one, :two].each do |parent|
    [false, true].each do |archived|
      test "#{parent} sees every class link counted when deleting an #{archived ? "archived" : "active"} learner" do
        sign_in users(parent)
        @maya.enrollments.destroy_all
        linked = %i[one completed archived].map { |label| courses(label) }
        [0, 1, 3].each do |count|
          @maya.restore! if @maya.archived?
          @maya.enrollments.destroy_all
          linked.first(count).each { |course| @maya.enrollments.create!(course: course) }
          @maya.archive! if archived
          get delete_learner_path(@maya)
          assert_select "h2", text: "Delete Maya?"
          assert_select "button", text: /Delete Maya/
          assert_select "p", text: /can't be undone/
          assert_select "p", text: archived ? /keep Maya archived/ : /archive instead/
          if count.zero?
            assert_no_match(/will be removed from/, response.body)
          else
            sentence = (count == 1) ? "Maya will be removed from 1 class, which stays for everyone else." : "Maya will be removed from 3 classes, which stay for everyone else."
            assert_select "p", text: sentence
          end
          assert_select "a", text: /Export/, count: 0
        end
        class_ids = @family.courses.pluck(:id).sort
        assert_difference "Enrollment.count", -3 do
          assert_difference "Learner.count", -1 do
            delete learner_path(@maya)
          end
        end
        assert_equal class_ids, @family.courses.pluck(:id).sort
      end
    end
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
