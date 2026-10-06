require "test_helper"

class StudentsIndexTest < ActionDispatch::IntegrationTest
  test "a parent sees active students as cards in creation order without archived ones" do
    # Fixtures share one timestamp; set explicit ones so creation order is unambiguous.
    students(:one).update_columns(created_at: 2.days.ago)
    students(:two).update_columns(created_at: 1.day.ago)
    sign_in users(:one)

    get students_path

    assert_response :success
    names = css_select(".grid p.font-medium").map { |node| node.text.strip }
    assert_equal %w[Maya Theo], names
    assert_no_match "Iris", response.body
  end

  test "grade level shows only for students who have one" do
    sign_in users(:one)

    get students_path

    assert_select ".grid p.text-muted-foreground", count: 1, text: "3rd"
  end

  test "each student card has a decorative color dot using its color token" do
    sign_in users(:one)

    get students_path

    assert_select ".grid span.student-color[data-student-color='sage'][aria-hidden='true']", count: 1
    assert_select ".grid span.student-color[data-student-color='sea'][aria-hidden='true']", count: 1
    assert_select ".grid span.student-color[style]", count: 0
  end

  test "a parent can open the add student modal from the add card" do
    students(:two).archive!
    sign_in users(:one)

    get students_path

    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 1
    assert_select "h2", text: "Add student"
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add student/
  end

  test "the add student card sits in the grid after the student cards" do
    students(:two).archive!
    sign_in users(:one)

    get students_path

    assert_select "h1 ~ button", count: 0
    assert_select "div.grid > div:last-child button[data-action='click->ui-modal#open:prevent']", text: /Add student/
  end

  test "a Free family at its limit sees a disabled add card with an upgrade link inside it" do
    sign_in users(:one)

    get students_path

    assert_select "div.grid [aria-disabled='true']" do
      assert_select "p", text: "Free includes 2 students."
      assert_select "a[href='#{pricing_path}']", text: /Upgrade to Premium/
    end
  end

  test "a Free family at its limit sees an upgrade prompt in place of the add card" do
    sign_in users(:one)

    get students_path

    assert_response :success
    assert_select "p.text-muted-foreground", text: "Free includes 2 students."
    assert_select "a[href='#{pricing_path}']", text: /Upgrade to Premium/
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
  end

  test "a Premium family at its limit is told to contact support" do
    account = accounts(:subscribed)
    account.update!(student_limit: 3)
    3.times { |i| Student.create!(account: account, name: "Student #{i}") }
    sign_in users(:subscribed)

    get students_path

    assert_select "p.text-muted-foreground", text: /Premium includes 3 students\. Need more\? Contact us\./
    assert_select "a[href^='mailto:']", text: "Contact us"
    assert_select "a[href='#{pricing_path}']", count: 0
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
  end

  test "a Complimentary Premium family at its limit is told to contact support" do
    account = accounts(:complimentary)
    10.times { |i| Student.create!(account: account, name: "Student #{i}") }
    sign_in users(:complimentary)

    get students_path

    assert_select "p.text-muted-foreground", text: /Premium includes 10 students\. Need more\?/
    assert_select "a[href^='mailto:']", text: "Contact us"
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
  end

  test "a Premium family with a raised limit can add students again" do
    account = accounts(:subscribed)
    account.update!(student_limit: 3)
    3.times { |i| Student.create!(account: account, name: "Student #{i}") }
    account.update!(student_limit: 4)
    sign_in users(:subscribed)

    get students_path

    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 1
    assert_select "a[href^='mailto:']", count: 0
  end

  test "a family under its limit sees the Add trigger and no prompt" do
    students(:two).archive!
    sign_in users(:one)

    get students_path

    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 1
    assert_select "a[href='#{pricing_path}']", count: 0
    assert_no_match "Free includes", response.body
  end

  test "a downgraded family sees the pick banner instead of student actions" do
    students(:kept).update!(kept_on_free: false)
    students(:kept_two).update!(kept_on_free: false)
    sign_in users(:downgraded)

    get students_path

    assert_select "p", text: "Premium ended. Choose which 2 students stay editable."
    assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_students_kept_path}']", count: 1
    assert_select "a[href='#{pricing_path}']", text: "Upgrade instead"
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
    assert_no_match "Free includes 2 students.", response.body
  end

  test "a downgraded family with a saved pick sees the quiet change note" do
    sign_in users(:downgraded)

    get students_path

    assert_select "p", text: "2 students are editable on Free."
    assert_select "button", text: "Change"
  end

  test "a downgraded family can view read-only students while its selected students remain editable" do
    sign_in users(:downgraded)

    get students_path

    [students(:kept), students(:kept_two)].each do |student|
      assert_select "[data-student='#{student.id}']" do
        assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_student_path(student)}']", count: 1
        assert_select "span", text: "Read-only", count: 0
      end
    end

    [students(:read_only), students(:read_only_two), students(:read_only_three)].each do |student|
      assert_select "[data-student='#{student.id}']" do
        assert_select "span", text: "Read-only", count: 1
        assert_select "[data-ui-modal-turbo-frame-src-value='#{student_path(student)}']", count: 1
        assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_student_path(student)}']", count: 0
        assert_select "button[data-action='click->ui-modal#open:prevent']", text: "View"
      end
    end
  end

  test "a Premium family can edit students even over the Free limit" do
    account = accounts(:subscribed)
    students = 3.times.map { |i| Student.create!(account: account, name: "Student #{i}") }
    sign_in users(:subscribed)

    get students_path

    students.each do |student|
      assert_select "[data-student='#{student.id}']" do
        assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_student_path(student)}']", count: 1
        assert_select "span", text: "Read-only", count: 0
        assert_select "[data-ui-modal-turbo-frame-src-value='#{student_path(student)}']", count: 0
      end
    end
  end

  test "a Free family at its limit cannot restore an archived student and is told to upgrade" do
    students(:two).archive!
    Student.create!(account: accounts(:company), name: "Iris Two")
    sign_in users(:one)

    get students_path(archived: 1)

    assert_select "section[aria-labelledby='archived-heading'] p.text-muted-foreground", text: /To restore a student, archive one first or upgrade to Premium\./
    assert_select "section[aria-labelledby='archived-heading'] a[href='#{pricing_path}']", text: "upgrade to Premium"
    assert_select "section[aria-labelledby='archived-heading'] form[action='#{student_archive_path(students(:two))}']", count: 0
    assert_select "section[aria-labelledby='archived-heading'] button", text: /Delete/
  end

  test "a Premium family at its limit is told to contact us before restoring" do
    account = accounts(:subscribed)
    account.update!(student_limit: 3)
    3.times { |i| Student.create!(account: account, name: "Student #{i}") }
    Student.create!(account: account, name: "Old", archived_at: 1.day.ago)
    sign_in users(:subscribed)

    get students_path(archived: 1)

    assert_select "section[aria-labelledby='archived-heading'] p.text-muted-foreground", text: /To restore a student, archive one first or contact us\./
    assert_select "section[aria-labelledby='archived-heading'] a[href^='mailto:']", text: "contact us"
    assert_select "section[aria-labelledby='archived-heading'] form[method='post'] input[name='_method'][value='delete']", count: 0
  end

  test "a family under its limit can restore archived students with no note" do
    students(:two).archive!
    sign_in users(:one)

    get students_path(archived: 1)

    assert_select "section[aria-labelledby='archived-heading'] form[action='#{student_archive_path(students(:two))}']", count: 1
    assert_select "section[aria-labelledby='archived-heading'] button", text: /Restore/
    assert_no_match "To restore a student", response.body
  end

  test "each card has an edit trigger for that student" do
    sign_in users(:one)

    get students_path

    [students(:one), students(:two)].each do |student|
      assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_student_path(student)}']", count: 1
      assert_select "h2", text: "Edit #{student.name}"
    end
  end

  test "a family with no active students sees an empty state with an add trigger" do
    sign_in users(:noaccount)

    get students_path

    assert_response :success
    assert_select "h2", text: "Add your first student"
    assert_select "p", text: "Each student gets a color so you can spot them across Cove."
    assert_select ".grid p.font-medium", count: 0
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 1
  end

  test "a family whose only students are archived sees the empty state" do
    students(:one).archive!
    students(:two).archive!
    sign_in users(:one)

    get students_path

    assert_select "h2", text: "Add your first student"
  end

  test "every student color has a token and views never hardcode hex colors" do
    css = File.read(Rails.root.join("app/assets/tailwind/application.css"))
    Student::COLORS.each do |color|
      assert_match(/--student-#{color}:\s*#\h{6};/, css, "missing --student-#{color} token")
    end

    Dir[Rails.root.join("app/views/students/**/*.erb")].each do |path|
      assert_no_match(/#\h{3,8}\b/, File.read(path), "hex value in #{path}")
    end
  end
end
