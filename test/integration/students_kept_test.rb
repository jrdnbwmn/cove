require "test_helper"

class StudentsKeptTest < ActionDispatch::IntegrationTest
  test "guests are sent to sign in and another family's id is rejected" do
    get edit_students_kept_path
    assert_redirected_to new_user_session_path

    sign_in users(:downgraded)
    patch students_kept_path, params: {student_ids: [students(:kept).id, students(:one).id]}
    assert_response :unprocessable_content
    assert_not students(:one).reload.kept_on_free?
  end

  test "a downgraded parent can open the picker and save two active students" do
    sign_in users(:downgraded)

    get edit_students_kept_path
    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "input[name='student_ids[]']", count: 5

    patch students_kept_path, params: {student_ids: [students(:read_only).id, students(:read_only_two).id]}

    assert_redirected_to students_path
    assert_predicate students(:read_only).reload, :kept_on_free?
    assert_predicate students(:read_only_two).reload, :kept_on_free?
  end

  test "malformed student ids show the picker error instead of failing" do
    sign_in users(:downgraded)

    patch students_kept_path, params: {student_ids: {"0" => students(:kept).id}}
    assert_response :unprocessable_content
    assert_match "Choose 2 students to keep editable.", response.body

    patch students_kept_path, params: {student_ids: "not-an-array"}
    assert_response :unprocessable_content
  end

  test "a rejected pick keeps the boxes the parent ticked" do
    sign_in users(:downgraded)

    patch students_kept_path, params: {student_ids: [students(:read_only).id]}

    assert_response :unprocessable_content
    assert_select "input[name='student_ids[]'][value='#{students(:read_only).id}'][checked]"
    assert_select "input[name='student_ids[]'][value='#{students(:kept).id}'][checked]", count: 0
  end

  test "the picker rejects invalid and stale selections and redirects when the limit no longer applies" do
    sign_in users(:downgraded)

    patch students_kept_path, params: {student_ids: [students(:kept).id]}
    assert_response :unprocessable_content
    assert_match "Choose 2 students to keep editable.", response.body

    students(:read_only).archive!
    students(:read_only_two).archive!
    students(:read_only_three).archive!
    get edit_students_kept_path
    assert_redirected_to students_path
  end
end
