require "test_helper"

class ComingSoonPagesTest < ActionDispatch::IntegrationTest
  test "redirects guests to sign in for schedules" do
    get schedules_path

    assert_redirected_to new_user_session_path
  end

  test "shows a coming-soon empty state for signed-in users on schedules" do
    sign_in users(:one)

    get schedules_path

    assert_response :success
    assert_select "h1", text: "Schedules"
    assert_select "h2", text: "Coming soon"
    assert_select "p", text: "Schedule planning will be available here."
    assert_select "svg path[d='M3 10h18']"
  end

  test "redirects guests to sign in for subjects" do
    get subjects_path

    assert_redirected_to new_user_session_path
  end

  test "shows a coming-soon empty state for signed-in users on subjects" do
    sign_in users(:one)

    get subjects_path

    assert_response :success
    assert_select "h1", text: "Subjects"
    assert_select "h2", text: "Coming soon"
    assert_select "p", text: "Subject management will be available here."
    assert_select "svg path[d='M12 7v14']"
  end

  test "redirects guests to sign in for students" do
    get students_path

    assert_redirected_to new_user_session_path
  end

  test "shows a coming-soon empty state for signed-in users on students" do
    sign_in users(:one)

    get students_path

    assert_response :success
    assert_select "h1", text: "Students"
    assert_select "h2", text: "Coming soon"
    assert_select "p", text: "Student management will be available here."
    assert_select "svg circle[cx='9'][cy='7'][r='4']"
  end
end
