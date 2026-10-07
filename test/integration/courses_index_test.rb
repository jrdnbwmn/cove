require "test_helper"

class CoursesIndexTest < ActionDispatch::IntegrationTest
  test "a parent sees classes ordered by subject with classes without a subject last" do
    sign_in users(:one)

    get courses_path

    assert_response :success
    names = css_select("[data-course] .course-name").map { |node| node.text.strip }
    assert_equal ["Piano", "Algebra 1", "Science Lab", "Nature study"], names
  end

  test "a class card shows its subject only when it has one" do
    sign_in users(:one)

    get courses_path

    assert_select "[data-course='#{courses(:one).id}'] .course-subject", text: "Math"
    assert_select "[data-course='#{courses(:no_subject).id}'] .course-subject", count: 0
  end

  test "a class card shows active learners and hides archived learners" do
    sign_in users(:one)

    get courses_path

    assert_select "[data-course='#{courses(:shared).id}']", text: /Maya/
    assert_select "[data-course='#{courses(:shared).id}']", text: /Theo/
    assert_select "[data-course='#{courses(:one).id}']", text: /No learners/
    assert_no_match "Iris", response.body
  end

  test "a read-only learner has a badge on their class" do
    sign_in users(:downgraded)

    get courses_path

    assert_select "[data-course='#{courses(:downgraded_course).id}'] span", text: "Read-only"
  end

  test "a class with no visible learners says no learners" do
    sign_in users(:one)

    get courses_path

    assert_select "[data-course='#{courses(:no_subject).id}']", text: /No learners/
  end

  test "an empty list shows its add action without a header add action" do
    accounts(:company).courses.destroy_all
    sign_in users(:one)

    get courses_path

    assert_select "h2", text: "No classes yet"
    assert_select "p", text: "Add a class for anything you want to track or grade, like Algebra 1, Piano, or Nature study."
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: "Add class", count: 1
    assert_select "[data-page-header-actions]", count: 0
  end

  test "the free-limit check is queried once while rendering class cards" do
    sign_in users(:downgraded)

    assert_queries_match(/SELECT COUNT\(\*\)/i, count: 1) { get courses_path }
  end
end
