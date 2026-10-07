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
    assert_select "h2", text: "Add class"
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

  private

  def assert_actions_in_order(labels)
    selector = "[data-course-actions] > div > button"
    texts = css_select(selector).map { |node| node.text.squish.sub(/ Working\.\.\.\z/, "") }
    assert_equal labels, texts
  end
end
