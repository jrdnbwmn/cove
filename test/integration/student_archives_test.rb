require "test_helper"

class StudentArchivesTest < ActionDispatch::IntegrationTest
  setup do
    @maya = students(:one)
    @archived = students(:archived)
    @other_family_student = Student.create!(account: accounts(:one), name: "Outsider")
  end

  test "guests are sent to sign in" do
    post student_archive_path(@maya)
    assert_redirected_to new_user_session_path

    delete student_archive_path(@archived)
    assert_redirected_to new_user_session_path
  end

  test "a parent can archive a student" do
    sign_in users(:one)

    post student_archive_path(@maya)

    assert_redirected_to students_path
    assert_equal "Maya archived.", flash[:notice]
    assert @maya.reload.archived?
  end

  test "the other parent can archive and restore too" do
    sign_in users(:two)

    post student_archive_path(@maya)
    assert @maya.reload.archived?

    delete student_archive_path(@maya)
    assert_not @maya.reload.archived?
  end

  test "archiving an already archived student changes nothing and still confirms" do
    sign_in users(:one)
    stamp = @archived.archived_at

    post student_archive_path(@archived)

    assert_redirected_to students_path
    assert_equal "Iris archived.", flash[:notice]
    assert_equal stamp.to_i, @archived.reload.archived_at.to_i
  end

  test "a parent can restore an archived student and the color is unchanged" do
    sign_in users(:one)
    color = @archived.color

    delete student_archive_path(@archived)

    assert_redirected_to students_path
    assert_equal "Iris restored.", flash[:notice]
    assert_not @archived.reload.archived?
    assert_equal color, @archived.color
  end

  test "restoring an active student changes nothing and still confirms" do
    sign_in users(:one)

    delete student_archive_path(@maya)

    assert_redirected_to students_path
    assert_equal "Maya restored.", flash[:notice]
    assert_not @maya.reload.archived?
  end

  test "another family's student cannot be archived or restored" do
    sign_in users(:one)

    post student_archive_path(@other_family_student)
    assert_response :not_found
    assert_not @other_family_student.reload.archived?

    sign_in users(:one)
    @other_family_student.update!(archived_at: Time.current)
    delete student_archive_path(@other_family_student)
    assert_response :not_found
    assert @other_family_student.reload.archived?
  end
end
