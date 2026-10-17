require "test_helper"

class ComingSoonPagesTest < ActionDispatch::IntegrationTest
  test "redirects guests to sign in for Planner" do
    get planner_path

    assert_redirected_to new_user_session_path
  end

  test "Planner keeps the Schedule placeholder with real tab links" do
    sign_in users(:one)

    get planner_path

    assert_response :success
    assert_select "h1", text: "Planner"
    assert_select "nav a[href=?][aria-current='page']", planner_path, text: "Schedule"
    assert_select "nav a[href=?]", planner_school_year_path, text: "School year"
    assert_select "h2", text: "Coming soon"
    assert_select "p", text: "Schedule planning will be available here."
    assert_select "svg path[d='M3 10h18']"
  end

  test "the old schedules URL permanently redirects to Planner" do
    get "/schedules"
    assert_response :moved_permanently
    assert_redirected_to planner_path
  end

  test "subjects no longer has a route" do
    sign_in users(:one)

    get "/subjects"

    assert_response :not_found
  end

  test "redirects guests to sign in for learners" do
    get learners_path

    assert_redirected_to new_user_session_path
  end

  test "shows the learners page instead of a coming-soon placeholder for signed-in users" do
    sign_in users(:one)

    get learners_path

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
