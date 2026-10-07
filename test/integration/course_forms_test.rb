require "test_helper"

class CourseFormsTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @course = courses(:shared)
    sign_in users(:one)
  end

  test "the add form has the class fields and only active learners" do
    get new_course_path

    assert_select "turbo-frame#modal-lazy-content"
    # The modal title comes from the Add class trigger, so the frame has no heading of its own.
    assert_select "turbo-frame#modal-lazy-content h2", count: 0
    assert_select "label[for='course_name']", text: /Name/
    assert_select "input#course_name[name='course[name]'][required][maxlength='75'][autofocus]"
    assert_select "p", text: "Something you want to track or grade, like Algebra 1 or Piano."
    assert_select "select[name='course[subject]'] option", text: "Choose or type a subject"
    assert_select "select[name='course[subject]'] option[value='Math']", text: "Math"
    assert_select "fieldset legend", text: "Learners"
    assert_select "fieldset", text: /Choose who takes this class\. You can leave it empty\./
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:one).id}']"
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:two).id}']"
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:archived).id}']", count: 0
    assert_select "button[type=submit][form='course-form']", text: /Add class/
    assert_actions_in_order ["Cancel", "Add class"]
  end

  test "a rejected add preserves the submitted subject, learners, and field error" do
    post courses_path, params: {course: {name: " ", subject: "Ceramics", learner_ids: [learners(:one).id]}}

    assert_response :unprocessable_content
    assert_select "p", text: "Enter a name for this class."
    assert_select "select[name='course[subject]'] option[value='Ceramics'][selected]", text: "Ceramics"
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:one).id}'][checked]"
  end

  test "the edit form shows visible selected learners but excludes archived learners" do
    get edit_course_path(@course)

    assert_select "turbo-frame#modal-lazy-content"
    assert_select "h2", text: "Edit class"
    assert_select "input#course_name[value='Science Lab']"
    assert_select "select[name='course[subject]'] option[value='Science'][selected]", text: "Science"
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:one).id}'][checked]"
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:two).id}'][checked]"
    assert_select "input[name='course[learner_ids][]'][value='#{learners(:archived).id}']", count: 0
    assert_select "button[type=submit][form='course-form']", text: /Save/
    assert_actions_in_order ["Cancel", "Save"]
  end

  test "the add form has no status field" do
    get new_course_path

    assert_select "select[name='course[status]']", count: 0
  end

  test "the edit form for an active class offers Active, Completed, and Archived" do
    get edit_course_path(courses(:one))

    assert_select "label", text: "Status"
    assert_select "select[name='course[status]'] option", count: 3
    assert_select "select[name='course[status]'] option[value='active'][selected]", text: "Active"
    assert_select "select[name='course[status]'] option[value='completed']", text: "Completed"
    assert_select "select[name='course[status]'] option[value='archived']", text: "Archived"
    assert_select "form#course-form select[name='course[status]']"
  end

  test "the edit form for a completed class offers Completed and Active with its date" do
    course = courses(:completed)
    get edit_course_path(course)

    assert_select "select[name='course[status]'] option", count: 2
    assert_select "select[name='course[status]'] option[value='completed'][selected]", text: "Completed"
    assert_select "select[name='course[status]'] option[value='active']", text: "Active"
    assert_select "p", text: "Completed #{helper_date(course.completed_at)}"
  end

  test "the edit form for an archived class offers Archived and Active with its date" do
    course = courses(:archived)
    get edit_course_path(course)

    assert_select "select[name='course[status]'] option", count: 2
    assert_select "select[name='course[status]'] option[value='archived'][selected]", text: "Archived"
    assert_select "select[name='course[status]'] option[value='active']", text: "Active"
    assert_select "p", text: "Archived #{helper_date(course.archived_at)}"
  end

  test "the edit form has no separate status buttons and the footer is unchanged" do
    get edit_course_path(courses(:completed))

    assert_select "form form", count: 0
    assert_select "button", text: /Complete class|Archive class|Reopen class|Restore class/, count: 0
    assert_actions_in_order ["Cancel", "Save"]
    assert_select "[data-course-actions] a", text: "Delete class"
  end

  test "an edit that fails validation still shows the saved status" do
    patch course_path(courses(:completed)), params: {course: {name: " ", status: "completed", learner_ids: [""]}}

    assert_response :unprocessable_content
    assert_select "select[name='course[status]'] option[value='completed'][selected]"
  end

  private

  def helper_date(time)
    ApplicationController.helpers.friendly_date(time)
  end

  def assert_actions_in_order(labels)
    selector = "[data-course-actions] > div > button"
    texts = css_select(selector).map { |node| node.text.squish.sub(/ Working\.\.\.\z/, "") }
    assert_equal labels, texts
  end
end
