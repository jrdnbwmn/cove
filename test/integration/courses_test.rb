require "test_helper"

class CoursesTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @course = courses(:one)
    @other_family_course = Course.create!(account: accounts(:one), name: "Outsider")
  end

  test "guests are sent to sign in" do
    get new_course_path
    assert_redirected_to new_user_session_path

    post courses_path, params: {course: {name: "Algebra 1"}}
    assert_redirected_to new_user_session_path
  end

  test "a parent can add a class with only a name, suggested subject, or custom subject" do
    sign_in users(:one)

    post courses_path, params: {course: {name: "Algebra 1", learner_ids: []}}
    assert_redirected_to courses_path
    assert_equal "Class added.", flash[:notice]
    assert_nil @family.courses.where(name: "Algebra 1").order(id: :desc).first.subject

    post courses_path, params: {course: {name: "Science", subject: "math", learner_ids: []}}
    assert_equal "Math", @family.courses.find_by!(name: "Science").subject

    post courses_path, params: {course: {name: "Co-op", subject: "Co-op", learner_ids: []}}
    assert_equal "Co-op", @family.courses.find_by!(name: "Co-op").subject
  end

  test "the other parent can add and edit a class" do
    sign_in users(:two)

    post courses_path, params: {course: {name: "Algebra 1", learner_ids: []}}
    course = @family.courses.find_by!(name: "Algebra 1")
    patch course_path(course), params: {course: {name: "Geometry", subject: "Math", learner_ids: []}}

    assert_redirected_to courses_path
    assert_equal "Geometry", course.reload.name
  end

  test "another family's class is not available to edit or update" do
    sign_in users(:one)

    get edit_course_path(@other_family_course)
    assert_response :not_found

    sign_in users(:one)
    patch course_path(@other_family_course), params: {course: {name: "Taken over", learner_ids: []}}
    assert_response :not_found
  end

  test "a read-only learner submitted with a class returns an inline error without saving" do
    sign_in users(:downgraded)

    assert_no_difference "Course.count" do
      post courses_path, params: {course: {name: "Algebra 1", learner_ids: [learners(:read_only).id]}}
    end

    assert_response :unprocessable_content
  end

  test "unchecking every learner clears the class" do
    sign_in users(:one)
    Enrollment.create!(course: @course, learner: learners(:one))

    patch course_path(@course), params: {course: {name: @course.name, subject: @course.subject, learner_ids: [""]}}

    assert_redirected_to courses_path
    assert_empty @course.reload.learners.active
  end

  test "an enrollment uniqueness race returns an inline error" do
    sign_in users(:one)
    Course.class_eval do
      alias_method :original_save_for_race_test, :save
      define_method(:save) { raise ActiveRecord::RecordNotUnique }
    end
    begin
      post courses_path, params: {course: {name: "Algebra 1", learner_ids: []}}
    ensure
      Course.class_eval do
        alias_method :save, :original_save_for_race_test
        remove_method :original_save_for_race_test
      end
    end

    assert_response :unprocessable_content
    assert_select "p", text: "One of these learners was just added to this class. Try saving again."
  end

  test "a parent can confirm and delete a class" do
    sign_in users(:one)
    Enrollment.create!(course: @course, learner: learners(:one))

    get delete_course_path(@course)
    assert_response :success
    assert_match "Delete Algebra 1?", response.body
    assert_select "p", text: "This can't be undone."

    assert_difference "Course.count", -1 do
      assert_difference "Enrollment.count", -@course.enrollments.count do
        delete course_path(@course)
      end
    end
    assert_redirected_to courses_path
    assert_equal "Class deleted.", flash[:notice]
  end

  test "Cancel on a delete confirmation from the edit modal goes back to the edit form" do
    sign_in users(:one)

    get delete_course_path(@course)

    assert_select "a[href='#{edit_course_path(@course)}']", text: /Cancel/
  end

  test "Cancel on a delete confirmation opened from the class list just closes the modal" do
    sign_in users(:one)

    get delete_course_path(@course, from: "list")

    assert_select "a[href='#{edit_course_path(@course)}']", count: 0
    assert_select "button[data-action='click->ui-modal#performClose:prevent']", text: /Cancel/
  end

  test "guests are sent to sign in when changing a class status" do
    post course_completion_path(@course)
    assert_redirected_to new_user_session_path

    delete course_archive_path(@course)
    assert_redirected_to new_user_session_path
  end

  test "a parent can mark a class complete and reopen it" do
    sign_in users(:one)

    post course_completion_path(@course)
    assert_redirected_to courses_path
    assert_equal "Algebra 1 is complete. Nice work.", flash[:notice]
    assert @course.reload.completed?

    delete course_completion_path(@course)
    assert_redirected_to courses_path
    assert_equal "Algebra 1 is active again.", flash[:notice]
    assert @course.reload.active?
  end

  test "a parent can archive a class and restore it" do
    sign_in users(:one)

    post course_archive_path(@course)
    assert_redirected_to courses_path
    assert_equal "Algebra 1 archived.", flash[:notice]
    assert @course.reload.archived?

    delete course_archive_path(@course)
    assert_redirected_to courses_path
    assert_equal "Algebra 1 restored.", flash[:notice]
    assert @course.reload.active?
  end

  test "a status change returns to the tab and filters the parent was on" do
    sign_in users(:one)
    referer = "http://www.example.com/classes?status=completed&learner=7&subject=Math"

    delete course_completion_path(courses(:completed)), headers: {"Referer" => referer}

    assert_redirected_to courses_path(status: "completed", learner: "7", subject: "Math")
  end

  test "a status change ignores a referrer that is not the class list" do
    sign_in users(:one)

    post course_completion_path(@course), headers: {"Referer" => "http://evil.example/classes?status=archived"}
    assert_redirected_to courses_path

    post course_archive_path(courses(:two)), headers: {"Referer" => "http://www.example.com/learners?status=archived"}
    assert_redirected_to courses_path
  end

  test "a stale or duplicate status request changes nothing and shows an alert" do
    sign_in users(:one)
    completed_at = courses(:completed).completed_at

    post course_completion_path(courses(:completed))
    assert_redirected_to courses_path
    assert_equal "Spanish 1 is already completed.", flash[:alert]
    assert_nil flash[:notice]

    post course_archive_path(courses(:completed))
    assert_equal "Only an active class can be completed or archived.", flash[:alert]

    post course_archive_path(courses(:archived))
    assert_equal "Woodworking is already archived.", flash[:alert]

    delete course_completion_path(@course)
    assert_equal "Only a completed class can be reopened.", flash[:alert]

    delete course_archive_path(courses(:completed))
    assert_equal "Only an archived class can be restored.", flash[:alert]

    assert_equal completed_at, courses(:completed).reload.completed_at
    assert courses(:archived).reload.archived?
    assert @course.reload.active?
  end

  test "another family's class cannot be completed, archived, reopened, or restored" do
    sign_in users(:one)
    @other_family_course.archive!

    [
      [:post, course_completion_path(@other_family_course)],
      [:delete, course_completion_path(@other_family_course)],
      [:delete, course_archive_path(@other_family_course)],
      [:post, course_archive_path(@other_family_course)]
    ].each do |verb, path|
      sign_in users(:one)
      public_send(verb, path)
      assert_response :not_found
    end

    assert @other_family_course.reload.archived?
  end

  test "adding, editing, or deleting a class returns to the tab and filters the parent was on" do
    sign_in users(:one)
    referer = {"Referer" => "http://www.example.com/classes?status=completed&learner=7&subject=Math"}
    list_path = courses_path(status: "completed", learner: "7", subject: "Math")

    post courses_path, params: {course: {name: "Geometry", learner_ids: []}}, headers: referer
    assert_redirected_to list_path

    patch course_path(@course), params: {course: {name: "Algebra 2", learner_ids: []}}, headers: referer
    assert_redirected_to list_path

    delete course_path(@course), headers: referer
    assert_redirected_to list_path
  end

  test "a class list return falls back to the class list for a missing, foreign, or malformed referrer" do
    sign_in users(:one)

    post courses_path, params: {course: {name: "Geometry", learner_ids: []}}
    assert_redirected_to courses_path

    ["http://evil.example/classes?status=archived", "http://www.example.com/learners?status=archived", "http://[bad"].each do |referer|
      patch course_path(@course), params: {course: {name: "Algebra 1", learner_ids: []}}, headers: {"Referer" => referer}
      assert_redirected_to courses_path
    end
  end

  test "a class list return keeps only the list's own parameters" do
    sign_in users(:one)

    patch course_path(@course), params: {course: {name: "Algebra 1", learner_ids: []}},
      headers: {"Referer" => "http://www.example.com/classes?status=archived&page=3&subject[]=a"}

    assert_redirected_to courses_path(status: "archived")
  end

  test "saving a class with a new status changes it and shows the status toast" do
    sign_in users(:one)

    patch course_path(@course), params: {course: {name: "Algebra 2", status: "completed", learner_ids: [""]}}
    assert_redirected_to courses_path
    assert_equal "Algebra 2 is complete. Nice work.", flash[:notice]
    assert @course.reload.completed?
    assert_equal "Algebra 2", @course.name

    patch course_path(@course), params: {course: {name: "Algebra 2", status: "active", learner_ids: [""]}}
    assert_equal "Algebra 2 is active again.", flash[:notice]
    assert @course.reload.active?

    patch course_path(@course), params: {course: {name: "Algebra 2", status: "archived", learner_ids: [""]}}
    assert_equal "Algebra 2 archived.", flash[:notice]
    assert @course.reload.archived?

    patch course_path(@course), params: {course: {name: "Algebra 2", status: "active", learner_ids: [""]}}
    assert_equal "Algebra 2 restored.", flash[:notice]
    assert @course.reload.active?
  end

  test "saving a class without changing its status says Saved and keeps its date" do
    sign_in users(:one)
    completed_at = courses(:completed).completed_at

    patch course_path(courses(:completed)), params: {course: {name: "Spanish 2", status: "completed", learner_ids: [""]}}

    assert_redirected_to courses_path
    assert_equal "Saved.", flash[:notice]
    assert_equal completed_at, courses(:completed).reload.completed_at
  end

  test "a status move the rules don't allow re-renders the form and changes nothing" do
    sign_in users(:one)

    patch course_path(courses(:completed)), params: {course: {name: "Renamed", status: "archived", learner_ids: [""]}}

    assert_response :unprocessable_content
    assert_select "p", text: "Only an active class can be completed or archived."
    assert courses(:completed).reload.completed?
    assert_equal "Spanish 1", courses(:completed).name
  end

  test "an unknown status is ignored when saving" do
    sign_in users(:one)

    patch course_path(@course), params: {course: {name: "Algebra 2", status: "bogus", learner_ids: [""]}}

    assert_equal "Saved.", flash[:notice]
    assert @course.reload.active?
  end

  test "a new class is always active even if a status is submitted" do
    sign_in users(:one)

    post courses_path, params: {course: {name: "Geometry", status: "completed", learner_ids: [""]}}

    assert @family.courses.find_by!(name: "Geometry").active?
  end
end
