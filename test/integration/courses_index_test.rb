require "test_helper"

class CoursesIndexTest < ActionDispatch::IntegrationTest
  test "a parent sees classes ordered by subject with classes without a subject last" do
    sign_in users(:one)

    get courses_path

    assert_response :success
    names = css_select("[data-course] .course-name").map { |node| node.text.strip }
    assert_equal ["Piano", "Algebra 1", "Science Lab", "Nature study"], names
  end

  test "classes share a bordered row list and each row opens its edit modal" do
    sign_in users(:one)

    get courses_path

    assert_select ".row-list", count: 1
    assert_select ".row-list > [data-course]", count: 4
    courses = [courses(:one), courses(:two), courses(:shared), courses(:no_subject)]
    courses.each do |course|
      assert_select "[data-course='#{course.id}'] [data-ui-modal-turbo-frame-src-value='#{edit_course_path(course)}']"
      assert_select "[data-course='#{course.id}'] .course-name button[data-action='click->ui-modal#open:prevent']", text: course.name
    end
  end

  test "a class row shows its subject only when it has one" do
    sign_in users(:one)

    get courses_path

    assert_select "[data-course='#{courses(:one).id}'] .course-subject", text: "Math"
    assert_select "[data-course='#{courses(:no_subject).id}'] .course-subject", text: ""
  end

  test "a class row shows active learners and hides archived learners" do
    sign_in users(:one)

    get courses_path

    assert_select "[data-course='#{courses(:shared).id}']", text: /Maya/
    assert_select "[data-course='#{courses(:shared).id}']", text: /Theo/
    assert_select "[data-course='#{courses(:one).id}']", text: /No learners/
    assert_no_match "Iris", response.body
  end

  test "class rows show active learners without badges on Free after downgrade" do
    sign_in users(:downgraded)

    get courses_path

    assert_response :success
    assert_select "[data-course='#{courses(:downgraded_course).id}'] .course-learners", text: /Casey/
    assert_select "[data-course='#{courses(:downgraded_course).id}'] .course-learners", text: /Avery/
    assert_no_match "Read-only", response.body
    accounts(:downgraded).learners.active.each do |learner|
      assert_select "select[name='learner'] option[value='#{learner.id}']", text: learner.name
    end

    get courses_path(learner: learners(:downgraded_three).id)

    assert_response :success
    assert_equal [courses(:downgraded_course).name], listed_names
    assert_select "select[name='learner'] option[selected][value='#{learners(:downgraded_three).id}']"
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
    assert_select ".row-list + [data-controller~='ui-modal']", count: 0
  end

  test "the Active class list ends with a row trigger that opens the plain Add class form" do
    sign_in users(:one)

    [{}, {learner: learners(:one).id, subject: "Science"}].each do |filters|
      get courses_path(**filters)

      assert_response :success
      assert_select ".row-list > [data-course]", minimum: 1
      assert_select ".row-list + [data-controller~='ui-modal']", count: 1
      assert_select ".row-list + [data-ui-modal-turbo-frame-src-value='#{new_course_path}']", count: 1 do
        assert_select "button.border-0[data-action='click->ui-modal#open:prevent']", text: "Add class"
        assert_select "dialog h2", text: "Add class"
      end
    end
  end

  test "the add class row trigger is absent from Completed and Archived lists" do
    sign_in users(:one)

    %w[completed archived].each do |status|
      get courses_path(status: status)

      assert_select ".row-list > [data-course]", minimum: 1
      assert_select ".row-list + [data-controller~='ui-modal']", count: 0
    end
  end

  test "filters that match no classes hide the add row trigger on every tab" do
    sign_in users(:one)

    %w[active completed archived].each do |status|
      get courses_path(status: status, subject: "Latin")

      assert_select "p", text: "No classes match these filters."
      assert_select ".row-list + [data-controller~='ui-modal']", count: 0
    end
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
    assert_select "h2", text: "No active classes"
    assert_select "p", text: "Find past classes under Completed and Archived, or add a new one."
    assert_select "h2", text: "No active classes" do |headings|
      assert_select headings.first.parent, "[data-ui-modal-turbo-frame-src-value='#{new_course_path}']" do
        assert_select "button[data-action='click->ui-modal#open:prevent']", text: "Add class"
      end
    end
    assert_select ".row-list + [data-controller~='ui-modal']", count: 0
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
    foreign = learners(:downgraded_one)

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

  test "a completed class row shows its completed date and no status date on active rows" do
    sign_in users(:one)

    get courses_path(status: "completed")

    date = ApplicationController.helpers.friendly_date(courses(:completed).completed_at)
    assert_select "[data-course='#{courses(:completed).id}'] .course-status-date", text: "Completed #{date}"

    get courses_path
    assert_select ".course-status-date", count: 0
  end

  test "an archived class row shows its archived date" do
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

  test "search and pagination appear together above twelve classes in the current filtered tab" do
    sign_in users(:one)
    8.times { |i| Course.create!(account: accounts(:company), name: "Extra #{i}", subject: "Science") }
    get courses_path
    assert_select "input[name='q']", count: 0
    assert_select "nav[aria-label='Pagination']", count: 0
    assert_select ".row-list > [data-course]", count: 12
    assert_select ".row-list + [data-ui-modal-turbo-frame-src-value='#{new_course_path}']"

    Course.create!(account: accounts(:company), name: "Extra last", subject: "Science")
    get courses_path
    assert_select "label[for='course_search']", text: "Search classes"
    assert_select "input[type='search'][name='q'][placeholder='Search classes']"
    assert_select "form[action='#{courses_path}'] button[type='submit']", text: /Search classes/
    assert_select "nav[aria-label='Pagination']"
    assert_select ".row-list > [data-course]", count: 12
    assert_select ".row-list + [data-ui-modal-turbo-frame-src-value='#{new_course_path}']", count: 0

    get courses_path(page: 2)
    assert_select ".row-list > [data-course]", count: 1
    assert_select ".row-list + [data-ui-modal-turbo-frame-src-value='#{new_course_path}']"
    get courses_path(subject: "Math")
    assert_select "input[name='q']", count: 0
    get courses_path(status: "completed")
    assert_select "input[name='q']", count: 0
  end

  test "search combines with filters and tab counts and stays visible with few matches" do
    sign_in users(:one)
    get courses_path(q: "mAtH", learner: learners(:two).id, subject: "math", status: "completed", page: 2)

    assert_equal ["Spanish 1"], listed_names
    assert_select "input[name='q'][value='mAtH']"
    assert_select "nav a", text: /Active\s*0/
    assert_select "nav a", text: /Completed\s*1/
    assert_select "nav a", text: /Archived\s*0/
    %w[active completed archived].each do |status|
      href = courses_path({status: (status unless status == "active"), learner: learners(:two).id, subject: "math", q: "mAtH"}.compact)
      assert_select "nav a[href='#{href}']"
    end
    assert_select "form[action='#{courses_path}'] input[name='page']", count: 0
    assert_select "nav[aria-label='Pagination']", count: 0
  end

  test "search finds names and subjects but excludes other families and learner names" do
    sign_in users(:one)
    Course.create!(account: accounts(:one), name: "Math outsider", subject: "Math")
    get courses_path(q: "math")
    assert_equal ["Algebra 1"], listed_names
    get courses_path(q: "lab")
    assert_equal ["Science Lab"], listed_names
    get courses_path(q: "Maya")
    assert_empty listed_names
  end

  test "search is trimmed bounded and escaped when echoed" do
    sign_in users(:one)
    get courses_path(q: "  math  ")
    assert_equal ["Algebra 1"], listed_names
    assert_select "input[name='q'][value='math']"

    get courses_path(q: "a" * 105)
    assert_select "input[name='q']" do |inputs|
      assert_equal "a" * 100, inputs.first["value"]
    end
    get courses_path(q: %(<script>alert("x")</script>))
    assert_select "input[name='q']" do |inputs|
      assert_equal %(<script>alert("x")</script>), inputs.first["value"]
    end
    assert_select "script", text: /alert/, count: 0
  end

  test "structured search is ignored and blank search is removed while keeping list state" do
    sign_in users(:one)
    ["q[]=math", "q[text]=math"].each do |query|
      get "/classes?#{query}"
      assert_response :success
      assert_equal 4, listed_names.size
      assert_select "input[name='q']", count: 0
    end
    ["", "   "].each do |query|
      get courses_path(q: query, status: "completed", learner: learners(:two).id, subject: "Math", page: 2)
      assert_redirected_to courses_path(status: "completed", learner: learners(:two).id, subject: "Math", page: "2")
      follow_redirect!
      assert_equal ["Spanish 1"], listed_names
    end
  end

  test "search no matches offers Clear all on the same tab" do
    sign_in users(:one)
    %w[active completed archived].each do |status|
      get courses_path(status: status, subject: "Math", q: "missing")
      assert_select "p", text: "No classes match your search or filters."
      assert_select "a[href='#{courses_path({status: (status unless status == "active")}.compact)}']", text: "Clear all"
      assert_select ".row-list", count: 0
      assert_select "nav[aria-label='Pagination']", count: 0
      assert_select "input[name='q'][value='missing']"
    end
  end

  test "invalid pages show the first page and overflowing pages show the last remaining page" do
    sign_in users(:one)
    10.times { |i| Course.create!(account: accounts(:company), name: "Extra #{i}") }
    get courses_path
    first_page = listed_names
    ["abc", "0", "-1", "1.5", "2junk", [], {number: "2"}].each do |page|
      get courses_path(page: page)
      assert_response :success
      assert_equal first_page, listed_names
    end
    get courses_path(page: 99)
    assert_response :success
    assert_equal 2, listed_names.size
    assert_select ".row-list + [data-ui-modal-turbo-frame-src-value='#{new_course_path}']"

    accounts(:company).courses.destroy_all
    get courses_path(page: 99)
    assert_response :success
    assert_select "h2", text: "No classes yet"
  end

  test "pagination links retain list state while tabs and filter submission reset page" do
    sign_in users(:one)
    13.times do |i|
      course = Course.create!(account: accounts(:company), name: "Math #{i}", subject: "Math", completed_at: Time.current)
      Enrollment.create!(course: course, learner: learners(:two))
    end
    get courses_path(status: "completed", learner: learners(:two).id, subject: "Math", q: "math", page: 2)
    assert_select "nav[aria-label='Pagination'] a[href]" do |links|
      links.each do |link|
        query = Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
        assert_equal "completed", query["status"]
        assert_equal learners(:two).id.to_s, query["learner"]
        assert_equal "Math", query["subject"]
        assert_equal "math", query["q"]
        assert query["page"]
      end
    end
    assert_select "form[action='#{courses_path}'] input[name='page']", count: 0
    assert_select "nav[aria-label='Class status'] a[href]" do |links|
      links.each { |link| assert_not_includes link["href"], "page=" }
    end
    assert_select ".row-list + [data-ui-modal-turbo-frame-src-value='#{new_course_path}']", count: 0
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
