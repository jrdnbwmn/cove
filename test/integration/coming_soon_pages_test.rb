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

  test "shows an explanatory empty state for signed-in users on subjects" do
    sign_in users(:one)

    get subjects_path

    assert_response :success
    assert_select "h1", text: "Subjects"
    assert_select "h2", text: "Subjects will live here"
    assert_select "p", text: "Use subjects to organize what each learner is learning when you start building school plans."
    assert_select "svg path[d='M12 7v14']"
  end

  test "redirects guests to sign in for students" do
    get students_path

    assert_redirected_to new_user_session_path
  end

  test "shows the students page instead of a coming-soon placeholder for signed-in users" do
    sign_in users(:one)

    get students_path

    assert_response :success
    assert_select "h1", text: "Learners"
    assert_select "h2", text: "Coming soon", count: 0
  end

  test "redirects guests to sign in for support" do
    get support_path

    assert_redirected_to new_user_session_path
  end

  test "gives signed-in users a way to contact support" do
    sign_in users(:one)

    get support_path

    assert_response :success
    assert_select "h1", text: "Support"
    assert_select "h2", text: "How can we help?"
    assert_select "p", text: "Include what you were trying to do and what happened so we can help."
    assert_select "a[href=?]", "mailto:#{Jumpstart.config.support_email}?subject=#{ERB::Util.url_encode("Help with Cove")}", text: "Email support"
  end
end
