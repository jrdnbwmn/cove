require "test_helper"

class StudentsIndexTest < ActionDispatch::IntegrationTest
  test "a parent sees active students as cards in creation order without archived ones" do
    # Fixtures share one timestamp; set explicit ones so creation order is unambiguous.
    students(:one).update_columns(created_at: 2.days.ago)
    students(:two).update_columns(created_at: 1.day.ago)
    sign_in users(:one)

    get students_path

    assert_response :success
    names = css_select(".grid p.font-medium")
      .reject { |node| node.ancestors.any? { |ancestor| ancestor["data-ui-modal-unsaved-changes-target"] == "discardPrompt" } }
      .map { |node| node.text.strip }
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

  test "a parent can open the add student modal from the header" do
    students(:two).archive!
    sign_in users(:one)

    get students_path

    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 1
    assert_select "h2", text: "Add student"
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add student/
  end

  test "a Free family at its limit still sees Add student, which opens a modal explaining the limit" do
    sign_in users(:one)

    get students_path

    assert_response :success
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add student/
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
    assert_select "dialog h2", text: "Free includes 2 students."
    assert_select "dialog", text: /Upgrade to Premium to add more students\./
    assert_select "dialog a[href='#{pricing_path}']", text: "See plans"
    assert_select "dialog button", text: "Close"
    assert_select "dialog a[href^='mailto:']", count: 0
  end

  test "a Premium family at its limit still sees Add student, with a Contact us action" do
    account = accounts(:subscribed)
    account.update!(student_limit: 3)
    3.times { |i| Student.create!(account: account, name: "Student #{i}") }
    sign_in users(:subscribed)

    get students_path

    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add student/
    assert_select "dialog h2", text: "Premium includes 3 students."
    assert_select "dialog a[href^='mailto:']", text: "Contact us"
    assert_select "dialog a[href='#{pricing_path}']", count: 0
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
  end

  test "a Complimentary Premium family at its limit is told to contact support" do
    account = accounts(:complimentary)
    10.times { |i| Student.create!(account: account, name: "Student #{i}") }
    sign_in users(:complimentary)

    get students_path

    assert_select "dialog h2", text: "Premium includes 10 students."
    assert_select "dialog a[href^='mailto:']", text: "Contact us"
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

  test "a downgraded family sees the pick banner and an Add student that explains the limit" do
    students(:kept).update!(kept_on_free: false)
    students(:kept_two).update!(kept_on_free: false)
    sign_in users(:downgraded)

    get students_path

    assert_select "p", text: "Premium ended. Choose which 2 students stay editable."
    assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_students_kept_path}']", count: 1
    assert_select "a[href='#{pricing_path}']", text: "Upgrade instead"
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 0
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add student/
    assert_select "dialog h2", text: "Free includes 2 students."
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
        assert_select "button[data-action='click->ui-modal#open:prevent']", text: student.name
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

    assert_select "p.text-muted-foreground", text: /To restore a student, archive one first or upgrade to Premium\./
    assert_select "a[href='#{pricing_path}']", text: "upgrade to Premium"
    assert_select "form[action='#{student_archive_path(students(:two))}']", count: 0
    assert_select "button", text: /Delete/
  end

  test "a Premium family at its limit is told to contact us before restoring" do
    account = accounts(:subscribed)
    account.update!(student_limit: 3)
    3.times { |i| Student.create!(account: account, name: "Student #{i}") }
    old = Student.create!(account: account, name: "Old", archived_at: 1.day.ago)
    sign_in users(:subscribed)

    get students_path(archived: 1)

    assert_select "p.text-muted-foreground", text: /To restore a student, archive one first or contact us\./
    assert_select "a[href^='mailto:']", text: "contact us"
    assert_select "form[action='#{student_archive_path(old)}']", count: 0
  end

  test "a family under its limit can restore archived students with no note" do
    students(:two).archive!
    sign_in users(:one)

    get students_path(archived: 1)

    assert_select "form[action='#{student_archive_path(students(:two))}']", count: 1
    assert_select "button", text: /Restore/
    assert_no_match "To restore a student", response.body
  end

  test "a family with archived students sees an Active/Archived control with counts" do
    sign_in users(:one)

    get students_path

    assert_select "nav[aria-label='Filter students']" do
      assert_select "a[href='#{students_path}'][aria-current='true']", text: /Active/
      assert_select "a[href='#{students_path(archived: 1)}']:not([aria-current])", text: /Archived/
    end
    assert_select "nav[aria-label='Filter students'] a", text: /Active\s*2/
    assert_select "nav[aria-label='Filter students'] a", text: /Archived\s*1/
  end

  test "a family with no archived students does not see the control" do
    sign_in users(:subscribed)

    get students_path

    assert_select "nav[aria-label='Filter students']", count: 0
  end

  test "the Archived view shows only archived students in the same grid" do
    sign_in users(:one)

    get students_path(archived: 1)

    assert_select "nav[aria-label='Filter students'] a[aria-current='true']", text: /Archived/
    names = css_select(".grid p.font-medium").map { |node| node.text.strip }
    assert_includes names, "Iris"
    assert_not_includes names, "Maya"
    assert_not_includes names, "Theo"
    assert_select "h2", text: "Archived", count: 0
  end

  test "a family whose students are all archived still sees the control above the empty state" do
    students(:one).archive!
    students(:two).archive!
    sign_in users(:one)

    get students_path

    assert_select "nav[aria-label='Filter students'] a[aria-current='true']", text: /Active\s*0/
    assert_select "nav[aria-label='Filter students'] a[href='#{students_path(archived: 1)}']", text: /Archived\s*3/
    assert_select "h2", text: "Add your first student"
  end

  test "an editable student's name opens their edit modal and the card has no footer buttons" do
    sign_in users(:one)

    get students_path

    assert_select "[data-student='#{students(:one).id}']" do
      assert_select "button[data-action='click->ui-modal#open:prevent']", text: "Maya"
      assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_student_path(students(:one))}']", count: 1
      assert_select "button", text: "Edit", count: 0
      assert_select "button[aria-label='Actions for Maya']", count: 1
    end
  end

  test "an active student's actions menu offers Archive and Delete" do
    sign_in users(:one)

    get students_path

    assert_select "[data-student='#{students(:one).id}']" do
      assert_select "[role='menuitem']", count: 2
      assert_select "button[role='menuitem'][type='submit'][form]", text: /Archive/
      assert_select "button[role='menuitem']", text: /Delete/
      assert_select "form[action='#{student_archive_path(students(:one))}'][method='post']", count: 1
      assert_select "[data-ui-modal-turbo-frame-src-value='#{delete_student_path(students(:one), from: "list")}']", count: 1
    end
  end

  test "a student's delete modal has no title of its own, so the confirmation heading is the only one" do
    sign_in users(:one)

    get students_path

    delete_modal = "[data-ui-modal-turbo-frame-src-value='#{delete_student_path(students(:one), from: "list")}']"
    assert_select delete_modal, count: 1
    assert_select "#{delete_modal} h2", count: 0
  end

  test "a read-only student's actions menu offers only Delete" do
    sign_in users(:downgraded)

    get students_path

    assert_select "[data-student='#{students(:read_only).id}']" do
      assert_select "[role='menuitem']", count: 1
      assert_select "button[role='menuitem']", text: /Delete/
      assert_select "form[action='#{student_archive_path(students(:read_only))}']", count: 0
    end
  end

  test "an archived student has no click target and its menu offers Restore and Delete" do
    students(:two).archive!
    sign_in users(:one)

    get students_path(archived: 1)

    assert_select "[data-student='#{students(:archived).id}']" do
      assert_select "p.font-medium button", count: 0
      assert_select "[role='menuitem']", count: 2
      assert_select "button[role='menuitem'][type='submit'][form]", text: /Restore/
      assert_select "button[role='menuitem']", text: /Delete/
    end
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
