require "test_helper"

class StudentsTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @maya = students(:one)
    @other_family_student = Student.create!(account: accounts(:one), name: "Outsider")
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
  end

  test "a parent can add a student with only a name and gets a color automatically" do
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
    sign_in users(:one)

    post students_path, params: {student: {name: "Nora", grade_level: "5th", color: "slate"}}

    student = @family.students.find_by!(name: "Nora")
    assert_equal "5th", student.grade_level
    assert_equal "slate", student.color
  end

  test "the other parent in the family can also add and edit students" do
    sign_in users(:two)

    post students_path, params: {student: {name: "Nora"}}
    assert_redirected_to students_path

    patch student_path(@maya), params: {student: {grade_level: "4th"}}
    assert_redirected_to students_path
    assert_equal "4th", @maya.reload.grade_level
  end

  test "student params cannot reassign the family" do
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
