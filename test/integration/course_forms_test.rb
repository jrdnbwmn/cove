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

  test "the add form has no status row" do
    get new_course_path

    assert_select "[data-course-status]", count: 0
  end

  test "the edit form shows an active class's status with Complete and Archive buttons" do
    get edit_course_path(courses(:one))

    assert_select "[data-course-status]" do
      assert_select "p", text: "Status"
      assert_select "p", text: "Active"
      assert_select "form[action='#{course_completion_path(courses(:one))}'][method='post'] button", text: /Complete class/
      assert_select "form[action='#{course_archive_path(courses(:one))}'][method='post'] button", text: /Archive class/
      assert_select "button", count: 2
    end
    assert_select "[data-course-status] form[data-discard-guard]", count: 2
  end

  test "the edit form shows a completed class's date with a Reopen button" do
    course = courses(:completed)
    get edit_course_path(course)

    assert_select "[data-course-status]" do
      assert_select "p", text: "Completed #{helper_date(course.completed_at)}"
      assert_select "form[action='#{course_completion_path(course)}'] input[name='_method'][value='delete']"
      assert_select "button", text: /Reopen class/
      assert_select "button", count: 1
    end
  end

  test "the edit form shows an archived class's date with a Restore button" do
    course = courses(:archived)
    get edit_course_path(course)

    assert_select "[data-course-status]" do
      assert_select "p", text: "Archived #{helper_date(course.archived_at)}"
      assert_select "form[action='#{course_archive_path(course)}'] input[name='_method'][value='delete']"
      assert_select "button", text: /Restore class/
      assert_select "button", count: 1
    end
  end

  test "the status buttons sit outside the class form and the footer is unchanged" do
    get edit_course_path(courses(:completed))

    assert_select "form#course-form [data-course-status]", count: 0
    assert_select "form form", count: 0
    assert_actions_in_order ["Cancel", "Save"]
    assert_select "[data-course-actions] a", text: "Delete class"
  end

  test "saving a completed or archived class keeps its status and date" do
    completed = courses(:completed)
    archived = courses(:archived)

    assert_no_changes -> { [completed.reload.completed_at, archived.reload.archived_at] } do
      patch course_path(completed), params: {course: {name: "Spanish 2", subject: "Arts", learner_ids: [""]}}
      patch course_path(archived), params: {course: {name: "Carpentry", subject: "Arts", learner_ids: [""]}}
    end
    assert completed.completed?
    assert archived.archived?
  end

  test "an edit that fails validation still shows the saved status" do
    patch course_path(courses(:completed)), params: {course: {name: " ", learner_ids: [""]}}

    assert_response :unprocessable_content
    assert_select "[data-course-status] button", text: /Reopen class/
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
