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

    assert_select ".grid span[aria-hidden='true'][style*='var(--student-sage)']", count: 1
    assert_select ".grid span[aria-hidden='true'][style*='var(--student-sea)']", count: 1
  end

  test "a parent can open the add student modal from the header" do
    sign_in users(:one)

    get students_path

    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_student_path}']", count: 1
    assert_select "h2", text: "Add student"
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add student/
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
