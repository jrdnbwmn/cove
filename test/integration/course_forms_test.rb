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

  test "class forms let a Free family select every active learner after downgrade" do
    family = accounts(:downgraded)
    archived = Learner.create!(account: family, name: "Archived learner")
    archived.archive!
    assert_not family.premium?
    assert_operator family.learners.active.count, :>, 2
    sign_in users(:downgraded)

    [new_course_path, edit_course_path(courses(:downgraded_course))].each do |path|
      get path

      assert_response :success
      family.learners.active.each do |learner|
        assert_select "input[type='checkbox'][name='course[learner_ids][]'][value='#{learner.id}']:not([disabled])"
      end
      assert_select "input[type='checkbox'][value='#{archived.id}']", count: 0
      assert_select "input[type='checkbox'][value='#{learners(:one).id}']", count: 0
      assert_no_match "Read-only", response.body
    end
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

  test "a class with no learners explains permanent deletion without a link count" do
    course = courses(:two)

    get delete_course_path(course)

    assert_response :success
    assert_select "h2", text: "Delete Piano?"
    assert_select "p", text: "This permanently removes Piano and can't be undone. To keep the class, archive instead."
    assert_select "p", text: /links? to .*learners?/, count: 0
    assert_select "button[type='submit'] .when-enabled", text: "Delete Piano"
  end

  test "a class counts a single archived learner when explaining removed links" do
    course = courses(:one)
    assert_equal [learners(:archived)], course.learners.to_a

    get delete_course_path(course)

    assert_response :success
    assert_select "p", text: "Algebra 1's link to 1 learner will be removed. The learner stays."
  end

  test "a class counts active and archived learners when explaining removed links" do
    learners(:archived).restore!
    Enrollment.create!(course: @course, learner: learners(:archived))
    learners(:archived).archive!

    get delete_course_path(@course)

    assert_response :success
    assert_select "p", text: "Science Lab's links to 3 learners will be removed. The learners stay."
  end

  test "every class status names deletion and offers the appropriate way to keep the class" do
    [courses(:one), courses(:completed), courses(:archived)].each do |course|
      get delete_course_path(course)

      assert_response :success
      assert_select "h2", text: "Delete #{course.name}?"
      assert_select "button[type='submit'] .when-enabled", text: "Delete #{course.name}"
      alternative = course.archived? ? "keep #{course.name} archived instead." : "archive instead."
      assert_select "p", text: "This permanently removes #{course.name} and can't be undone. To keep the class, #{alternative}"
      assert_select "turbo-frame#modal-lazy-content form", count: 1
      assert_select "form[action='#{course_path(course)}'] input[name='_method'][value='delete']"
      assert_select "a[href='#{edit_course_path(course)}']", text: /Cancel/
      assert_select "button, a", text: /\A(?:Archive class|Complete class|Restore class|Reopen class)\z/, count: 0
    end
  end

  test "deleting classes in every status retains their learners and returns to the existing tab and filters" do
    [courses(:shared), courses(:completed), courses(:archived)].each do |course|
      learners(:archived).restore!
      Enrollment.create!(course: course, learner: learners(:archived))
      learners(:archived).archive!
      learner_ids = course.learners.pluck(:id)
      link_count = course.enrollments.count
      list_path = courses_path(status: course.status, learner: learners(:two).id, subject: "Science")

      get delete_course_path(course, from: "list"), headers: {"Referer" => "http://www.example.com#{list_path}"}

      assert_response :success
      assert_select "button[data-action='click->ui-modal#performClose:prevent']", text: /Cancel/
      assert_select "a[href='#{edit_course_path(course)}']", count: 0
      assert_no_difference "Learner.count" do
        assert_difference "Course.count", -1 do
          assert_difference "Enrollment.count", -link_count do
            delete course_path(course), headers: {"Referer" => "http://www.example.com#{list_path}"}
          end
        end
      end

      assert_redirected_to list_path
      assert_equal "Class deleted.", flash[:notice]
      assert_equal learner_ids.sort, Learner.where(id: learner_ids).pluck(:id).sort
      assert learners(:archived).reload.archived?
    end
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
