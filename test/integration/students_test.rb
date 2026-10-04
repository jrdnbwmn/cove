require "test_helper"

class StudentsTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @maya = students(:one)
    @other_family_student = Student.create!(account: accounts(:one), name: "Outsider")
  end

  # The Free fixture family starts at its 2-student limit; archiving Theo opens a slot.
  def open_student_slot
    students(:two).archive!
  end

  test "a parent cannot add a student past the family limit and keeps what they typed" do
    sign_in users(:one)

    assert_no_difference -> { Student.count } do
      post students_path, params: {student: {name: "Nora", grade_level: "5th"}}
    end

    assert_response :unprocessable_content
    assert_match "Free includes 2 students. Upgrade to Premium to add more.", response.body
    assert_select "input[name='student[name]'][value='Nora']"
    assert_select "input[name='student[grade_level]'][value='5th']"
  end

  test "a parent can still edit and archive a selected student while over the family limit" do
    sign_in users(:one)
    Student.new(account: @family, name: "Extra", color: "rose").save!(validate: false)
    @maya.update!(kept_on_free: true)

    patch student_path(@maya), params: {student: {grade_level: "4th"}}
    assert_redirected_to students_path
    assert_equal "4th", @maya.reload.grade_level

    post student_archive_path(@maya)
    assert_redirected_to students_path
    assert @maya.reload.archived?
  end

  test "guests are sent to sign in" do
    get new_student_path
    assert_redirected_to new_user_session_path

    post students_path, params: {student: {name: "Maya"}}
    assert_redirected_to new_user_session_path
  end

  test "a parent can open the add form inside the modal frame" do
    sign_in users(:one)

    get new_student_path

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "input[name='student[name]']"
    assert_select "span.student-color[data-student-color='sage']"
    assert_select "span.student-color[style]", count: 0
  end

  test "a parent can add a student with only a name and gets a color automatically" do
    open_student_slot
    sign_in users(:one)

    assert_difference -> { @family.students.count }, 1 do
      post students_path, params: {student: {name: "  Nora  "}}
    end

    student = @family.students.find_by!(name: "Nora")
    assert_includes Student::COLORS, student.color
    assert_nil student.grade_level
    assert_redirected_to students_path
    assert_equal "Nora added.", flash[:notice]
  end

  test "a parent can add a student with a grade level and color" do
    open_student_slot
    sign_in users(:one)

    post students_path, params: {student: {name: "Nora", grade_level: "5th", color: "slate"}}

    student = @family.students.find_by!(name: "Nora")
    assert_equal "5th", student.grade_level
    assert_equal "slate", student.color
  end

  test "the other parent in the family can also add and edit students" do
    open_student_slot
    sign_in users(:two)

    post students_path, params: {student: {name: "Nora"}}
    assert_redirected_to students_path

    patch student_path(@maya), params: {student: {grade_level: "4th"}}
    assert_redirected_to students_path
    assert_equal "4th", @maya.reload.grade_level
  end

  test "student params cannot reassign the family" do
    open_student_slot
    sign_in users(:one)

    post students_path, params: {student: {name: "Nora", account_id: accounts(:one).id, archived_at: Time.current}}

    student = Student.find_by!(name: "Nora")
    assert_equal @family, student.account
    assert_nil student.archived_at
  end

  test "adding a student with a blank name shows the error and keeps typed values" do
    sign_in users(:one)

    assert_no_difference -> { Student.count } do
      post students_path, params: {student: {name: " ", grade_level: "5th", color: "slate"}}
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "Enter a name to continue.", response.body
    assert_select "input[name='student[grade_level]'][value='5th']"
  end

  test "adding a duplicate name is refused ignoring case and keeps typed values" do
    sign_in users(:one)

    assert_no_difference -> { Student.count } do
      post students_path, params: {student: {name: " MAYA ", grade_level: "7th"}}
    end

    assert_response :unprocessable_content
    assert_match "You already have a student named MAYA.", response.body
    assert_select "input[name='student[grade_level]'][value='7th']"
  end

  test "adding a name that matches an archived student explains how to restore them" do
    sign_in users(:one)

    post students_path, params: {student: {name: "Iris"}}

    assert_response :unprocessable_content
    assert_match "archived student named Iris", response.body
  end

  test "a duplicate created by the other parent at the same moment is shown as a duplicate" do
    open_student_slot
    sign_in users(:one)

    with_friendly_uniqueness_check_disabled do
      assert_no_difference -> { Student.count } do
        post students_path, params: {student: {name: "maya", grade_level: "7th"}}
      end
    end

    assert_response :unprocessable_content
    assert_match "You already have a student named maya.", response.body
    assert_select "input[name='student[grade_level]'][value='7th']"
  end

  test "a parent can open the edit form for an active student" do
    sign_in users(:one)

    get edit_student_path(@maya)

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "input[name='student[name]'][value='Maya']"
  end

  test "a parent can edit a student's name, grade and color" do
    sign_in users(:one)

    patch student_path(@maya), params: {student: {name: "Maya R", grade_level: "", color: "rose"}}

    assert_redirected_to students_path
    assert_equal "Saved.", flash[:notice]
    @maya.reload
    assert_equal "Maya R", @maya.name
    assert_nil @maya.grade_level
    assert_equal "rose", @maya.color
  end

  test "a student can be saved with their own name unchanged" do
    sign_in users(:one)

    patch student_path(@maya), params: {student: {name: "maya", grade_level: "8th"}}

    assert_redirected_to students_path
    assert_equal "maya", @maya.reload.name
  end

  test "editing with an invalid value shows the error and keeps typed values" do
    sign_in users(:one)

    patch student_path(@maya), params: {student: {name: "Theo", grade_level: "9th"}}

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "You already have a student named Theo.", response.body
    assert_select "input[name='student[grade_level]'][value='9th']"
    assert_equal "Maya", @maya.reload.name
  end

  test "an edit that loses a duplicate race is shown as a duplicate" do
    sign_in users(:one)

    with_friendly_uniqueness_check_disabled do
      patch student_path(@maya), params: {student: {name: "theo"}}
    end

    assert_response :unprocessable_content
    assert_match "You already have a student named theo.", response.body
    assert_equal "Maya", @maya.reload.name
  end

  test "archived students cannot be edited" do
    sign_in users(:one)

    get edit_student_path(students(:archived))
    assert_redirected_to students_path

    patch student_path(students(:archived)), params: {student: {name: "Changed"}}
    assert_redirected_to students_path
    assert_equal "Iris", students(:archived).reload.name
  end

  test "a parent cannot open or directly save a read-only student's edit form" do
    student = students(:read_only)
    sign_in users(:downgraded)

    get edit_student_path(student)
    assert_redirected_to students_path
    assert_equal "Casey can't be edited on Free. You can still archive or delete this student.", flash[:alert]

    patch student_path(student), params: {student: {name: "Changed"}}
    assert_redirected_to students_path
    assert_equal "Casey", student.reload.name
  end

  test "a selected student and all students after re-subscribing can be edited" do
    sign_in users(:downgraded)

    get edit_student_path(students(:kept))
    assert_response :success

    accounts(:downgraded).update!(complimentary_premium: true, complimentary_premium_note: "Temporary Premium")
    get edit_student_path(students(:read_only))
    assert_response :success
  end

  test "another family's student cannot be edited or updated" do
    sign_in users(:one)

    get edit_student_path(@other_family_student)
    assert_response :not_found

    # The 404 aborts the request before Warden persists the session, so sign in again.
    sign_in users(:one)
    patch student_path(@other_family_student), params: {student: {name: "Taken over"}}
    assert_response :not_found
    assert_equal "Outsider", @other_family_student.reload.name
  end

  test "the edit form offers archive and delete for an active student" do
    sign_in users(:one)

    get edit_student_path(@maya)

    assert_select "form[action='#{student_archive_path(@maya)}'][method='post'] button", text: /\AArchive/
    assert_select "a[href='#{delete_student_path(@maya)}']", text: "Delete"
  end

  test "a parent sees a delete confirmation inside the modal frame" do
    sign_in users(:one)

    get delete_student_path(@maya)

    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_match "Delete Maya?", response.body
    assert_match "permanently removes Maya", response.body
    assert_select "form[action='#{student_path(@maya)}'] input[name='_method'][value='delete']"
    assert_select "a[href='#{edit_student_path(@maya)}']", text: "Cancel"
  end

  test "a parent can view a read-only student and return there from delete confirmation" do
    sign_in users(:downgraded)

    get student_path(students(:read_only))
    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "p", text: /Casey can't be edited on Free/

    get delete_student_path(students(:read_only))
    assert_select "a[href='#{student_path(students(:read_only))}']", text: "Cancel"
  end

  test "viewing an editable student sends the parent to the edit form instead" do
    sign_in users(:downgraded)

    get student_path(students(:kept))
    assert_redirected_to edit_student_path(students(:kept))

    sign_in users(:one)
    get student_path(students(:one))
    assert_redirected_to edit_student_path(students(:one))
  end

  test "guests and other families cannot view a student" do
    get student_path(students(:read_only))
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    get student_path(students(:read_only))
    assert_response :not_found
  end

  test "cancelling the confirmation for an archived student closes the modal" do
    sign_in users(:one)

    get delete_student_path(students(:archived))

    assert_response :success
    assert_select "a[href='#{edit_student_path(students(:archived))}']", count: 0
    assert_select "button[data-action='click->ui-modal#close:prevent']", text: "Cancel"
  end

  test "a parent can permanently delete a student" do
    sign_in users(:one)

    assert_difference -> { @family.students.count }, -1 do
      delete student_path(@maya)
    end

    assert_redirected_to students_path
    assert_equal "Maya deleted.", flash[:notice]
    assert_not Student.exists?(@maya.id)
  end

  test "the other parent can delete a student and an archived student can be deleted" do
    sign_in users(:two)

    delete student_path(students(:archived))

    assert_redirected_to students_path
    assert_not Student.exists?(students(:archived).id)
  end

  test "another family's student cannot be deleted or confirmed for deletion" do
    sign_in users(:one)

    get delete_student_path(@other_family_student)
    assert_response :not_found

    sign_in users(:one)
    assert_no_difference -> { Student.count } do
      delete student_path(@other_family_student)
    end
    assert_response :not_found
  end

  private

  # AIDEV-NOTE: Simulates two parents saving the same name at once: with the friendly
  # model check skipped, only the unique index stands between the write and a duplicate.
  def with_friendly_uniqueness_check_disabled
    Student.class_eval do
      alias_method :original_name_unique_within_account, :name_unique_within_account
      define_method(:name_unique_within_account) {}
    end
    yield
  ensure
    Student.class_eval do
      alias_method :name_unique_within_account, :original_name_unique_within_account
      remove_method :original_name_unique_within_account
    end
  end
end
