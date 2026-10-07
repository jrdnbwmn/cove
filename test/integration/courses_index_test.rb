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

  test "the filter toolbar and status tabs show when the family has classes" do
    sign_in users(:one)

    get courses_path

    assert_select "form[action='#{courses_path}'][method='get']" do
      assert_select "select[name='learner']"
      assert_select "select[name='subject']"
      assert_select "input[type='hidden'][name='status'][value='active']"
      assert_select "label", text: "Filter by learner"
      assert_select "label", text: "Filter by subject"
      assert_select "[data-select-submit-on-change-value='true']", count: 2
    end
    assert_select "select[name='learner'] option[value='']", text: "All learners"
    assert_select "select[name='subject'] option[value='']", text: "All subjects"
    assert_select "select[name='learner'] option", text: "Iris", count: 0
  end

  test "the toolbar reflects the selected filters and keeps the current tab" do
    sign_in users(:one)

    get courses_path(status: "completed", learner: learners(:two).id, subject: "math")

    assert_select "select[name='learner'] option[selected][value='#{learners(:two).id}']"
    assert_select "select[name='subject'] option[selected]", text: "Math"
    assert_select "input[type='hidden'][name='status'][value='completed']"
  end

  test "the status tabs link to each tab with counts and keep learner and subject" do
    sign_in users(:one)

    get courses_path(learner: learners(:two).id, subject: "math")

    assert_select "nav a[href='#{courses_path(learner: learners(:two).id, subject: "math")}'][aria-current]", text: /Active/
    assert_select "nav a[href='#{courses_path(status: "completed", learner: learners(:two).id, subject: "math")}']", text: /Completed/
    assert_select "nav a[href='#{courses_path(status: "archived", learner: learners(:two).id, subject: "math")}']", text: /Archived/
  end

  test "the status tabs show counts for the current filters" do
    sign_in users(:one)

    get courses_path

    assert_select "nav a", text: /Active\s*4/
    assert_select "nav a", text: /Completed\s*1/
    assert_select "nav a", text: /Archived\s*1/

    get courses_path(subject: "Math")

    assert_select "nav a", text: /Active\s*1/
    assert_select "nav a", text: /Completed\s*1/
    assert_select "nav a", text: /Archived\s*0/
  end

  test "a family with no classes sees no toolbar or tabs" do
    accounts(:company).courses.destroy_all
    sign_in users(:one)

    get courses_path

    assert_select "form[action='#{courses_path}'][method='get']", count: 0
    assert_select "select[name='learner']", count: 0
    assert_select "nav a", text: /Completed/, count: 0
  end

  test "a family whose classes are all completed still sees the toolbar, tabs, and add action" do
    accounts(:company).courses.active.destroy_all
    accounts(:company).courses.archived.destroy_all
    sign_in users(:one)

    get courses_path

    assert_select "h2", text: "No classes yet", count: 0
    assert_select "form[action='#{courses_path}'][method='get']"
    assert_select "[data-page-header-actions] button", text: "Add class"
    assert_select "p", text: "No active classes. Add one, or find past classes under Completed and Archived."
  end

  test "the header add action shows on every tab" do
    sign_in users(:one)

    %w[active completed archived].each do |status|
      get courses_path(status: status)

      assert_select "[data-page-header-actions] button", text: "Add class"
    end
  end

  test "an empty Completed tab says nothing is completed yet" do
    accounts(:company).courses.completed.destroy_all
    sign_in users(:one)

    get courses_path(status: "completed")

    assert_select "p", text: "No completed classes yet."
    assert_select "a", text: "Clear filters", count: 0
  end

  test "an empty Archived tab says nothing is archived" do
    accounts(:company).courses.archived.destroy_all
    sign_in users(:one)

    get courses_path(status: "archived")

    assert_select "p", text: "No archived classes."
    assert_select "a", text: "Clear filters", count: 0
  end

  test "filters that match nothing offer a way to clear them on the same tab" do
    sign_in users(:one)

    get courses_path(status: "completed", subject: "Latin", learner: learners(:one).id)

    assert_select "p", text: "No classes match these filters."
    assert_select "a[href='#{courses_path(status: "completed")}']", text: "Clear filters"
    assert_select "p", text: "No completed classes yet.", count: 0

    get courses_path(subject: "Latin")

    assert_select "a[href='#{courses_path}']", text: "Clear filters"
  end

  test "filters that match nothing on the Archived tab show the no-match state not the tab empty copy" do
    sign_in users(:one)

    get courses_path(status: "archived", subject: "Math")

    assert_select "p", text: "No classes match these filters."
    assert_select "p", text: "No archived classes.", count: 0
  end

  test "an empty Active tab with filters shows the no-match state" do
    sign_in users(:one)

    get courses_path(subject: "Latin")

    assert_select "p", text: "No classes match these filters."
    assert_select "p", text: /No active classes/, count: 0
  end

  test "the free-limit check is queried once while rendering class cards" do
    sign_in users(:downgraded)

    assert_queries_match(/SELECT COUNT\(\*\) FROM "learners"/i, count: 1) { get courses_path }
  end

  def listed_names
    css_select("[data-course] .course-name").map { |node| node.text.strip }
  end

  test "the class list shows only active classes by default" do
    sign_in users(:one)

    get courses_path

    assert_not_includes listed_names, "Spanish 1"
    assert_not_includes listed_names, "Woodworking"
  end

  test "a parent can see completed classes on the Completed tab" do
    sign_in users(:one)

    get courses_path(status: "completed")

    assert_equal ["Spanish 1"], listed_names
  end

  test "a parent can find archived classes on the Archived tab" do
    sign_in users(:one)

    get courses_path(status: "archived")

    assert_equal ["Woodworking"], listed_names
  end

  test "a class completed from the list leaves the Active list" do
    sign_in users(:one)

    post course_completion_path(courses(:one))
    get courses_path

    assert_not_includes listed_names, "Algebra 1"
  end

  test "a parent can filter classes by learner" do
    sign_in users(:one)

    get courses_path(learner: learners(:one).id)

    assert_equal ["Science Lab"], listed_names
  end

  test "a parent can filter classes by subject ignoring case" do
    sign_in users(:one)

    get courses_path(subject: "math")

    assert_equal ["Algebra 1"], listed_names
  end

  test "filters combine with each other and with the status tab" do
    sign_in users(:one)

    get courses_path(status: "completed", learner: learners(:two).id, subject: "MATH")
    assert_equal ["Spanish 1"], listed_names

    get courses_path(status: "completed", learner: learners(:one).id, subject: "Math")
    assert_empty listed_names

    get courses_path(learner: learners(:two).id, subject: "Science")
    assert_equal ["Science Lab"], listed_names
  end

  test "an unknown status falls back to the Active list" do
    sign_in users(:one)

    get courses_path(status: "bogus")

    assert_response :success
    assert_equal ["Piano", "Algebra 1", "Science Lab", "Nature study"], listed_names
  end

  test "an unknown, foreign, archived, or malformed learner is ignored" do
    sign_in users(:one)
    foreign = learners(:kept)

    [foreign.id, learners(:archived).id, 0, "abc", "1; DROP TABLE courses"].each do |value|
      get courses_path(learner: value)

      assert_response :success
      assert_equal ["Piano", "Algebra 1", "Science Lab", "Nature study"], listed_names, "learner=#{value} should be ignored"
    end

    get "/classes?learner[]=1&subject[]=Math&status[]=archived"
    assert_response :success
    assert_equal ["Piano", "Algebra 1", "Science Lab", "Nature study"], listed_names
  end

  test "a subject that is no longer in use applies and matches nothing" do
    sign_in users(:one)

    get courses_path(subject: "Latin")

    assert_response :success
    assert_empty listed_names
  end

  test "a class added from a non-Active tab does not appear on that tab" do
    sign_in users(:one)

    post courses_path, params: {course: {name: "Geometry", learner_ids: []}},
      headers: {"Referer" => "http://www.example.com/classes?status=completed"}
    follow_redirect!

    assert_equal ["Spanish 1"], listed_names
    get courses_path
    assert_includes listed_names, "Geometry"
  end

  test "a class in another family never appears in filters or tabs" do
    other = Course.create!(account: accounts(:one), name: "Outsider", subject: "Math")
    sign_in users(:one)

    get courses_path(subject: "Math")

    assert_equal ["Algebra 1"], listed_names
    assert_not_includes listed_names, other.name
  end

  test "the number of queries does not grow with the number of classes" do
    sign_in users(:one)
    get courses_path(status: "completed", learner: learners(:two).id, subject: "Math")
    baseline = count_queries { get courses_path(status: "completed", learner: learners(:two).id, subject: "Math") }

    8.times do |index|
      course = Course.create!(account: accounts(:company), name: "Extra #{index}", subject: "Math")
      Enrollment.create!(course: course, learner: learners(:two))
      course.complete!
    end

    assert_equal baseline, count_queries { get courses_path(status: "completed", learner: learners(:two).id, subject: "Math") }
  end

  test "a completed class card shows its completed date and no status date on active cards" do
    sign_in users(:one)

    get courses_path(status: "completed")

    date = ApplicationController.helpers.friendly_date(courses(:completed).completed_at)
    assert_select "[data-course='#{courses(:completed).id}'] .course-status-date", text: "Completed #{date}"

    get courses_path
    assert_select ".course-status-date", count: 0
  end

  test "an archived class card shows its archived date" do
    sign_in users(:one)

    get courses_path(status: "archived")

    date = ApplicationController.helpers.friendly_date(courses(:archived).archived_at)
    assert_select "[data-course='#{courses(:archived).id}'] .course-status-date", text: "Archived #{date}"
  end

  test "an active class menu offers edit, complete, archive, and delete" do
    sign_in users(:one)
    course = courses(:one)

    get courses_path

    assert_select "[data-course='#{course.id}'] button[aria-label='Actions for Algebra 1'][aria-haspopup='menu']"
    assert_equal %w[Edit Complete Archive Delete], menu_items(course)
    assert_hidden_form "edit_course_#{course.id}", method: "get"
    assert_hidden_form "complete_course_#{course.id}", action: course_completion_path(course), method: "post"
    assert_hidden_form "archive_course_#{course.id}", action: course_archive_path(course), method: "post"
    assert_hidden_form "delete_course_#{course.id}", method: "get"
    assert_select "[data-ui-modal-turbo-frame-src-value='#{delete_course_path(course, from: "list")}']"
  end

  test "a completed class menu offers edit, reopen, and delete" do
    sign_in users(:one)
    course = courses(:completed)

    get courses_path(status: "completed")

    assert_equal %w[Edit Reopen Delete], menu_items(course)
    assert_hidden_form "reopen_course_#{course.id}", action: course_completion_path(course), method: "post", override: "delete"
  end

  test "an archived class menu offers edit, restore, and delete" do
    sign_in users(:one)
    course = courses(:archived)

    get courses_path(status: "archived")

    assert_equal %w[Edit Restore Delete], menu_items(course)
    assert_hidden_form "restore_course_#{course.id}", action: course_archive_path(course), method: "post", override: "delete"
  end

  private

  def menu_items(course)
    css_select("[data-course='#{course.id}'] button[type='submit'][form]").map { |node| node.text.strip }
  end

  def assert_hidden_form(id, method:, action: nil, override: nil)
    assert_select "[data-course] form##{id}.hidden[method='#{method}']" do |forms|
      assert_equal action, forms.first["action"] if action
    end
    assert_select "form##{id} input[name='_method'][value='#{override}']" if override
  end

  def count_queries(&block)
    count = 0
    # Cache hits count too, so an N+1 hidden by the query cache would still show up.
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
