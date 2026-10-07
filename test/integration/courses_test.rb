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
    assert_empty @course.reload.visible_learners
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
end
