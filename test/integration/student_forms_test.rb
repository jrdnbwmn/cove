require "test_helper"

class StudentFormsTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @maya = students(:one)
    sign_in users(:one)
  end

  test "the add form has labelled name and grade fields limited to 50 characters" do
    get new_student_path

    assert_select "label[for='student_name']", text: /Name/
    assert_select "input#student_name[name='student[name]'][maxlength='50'][autofocus]"
    assert_select "label[for='student_grade_level']", text: /Grade level/
    assert_select "input#student_grade_level[name='student[grade_level]'][maxlength='50'][placeholder='e.g. 3rd, Pre-K']"
  end

  test "the add form offers the next color pre-selected and an Add student button" do
    get new_student_path

    assert_select "button[type=submit]", text: /Add student/
    assert_select "input[type=radio][name='student[color]'][checked]", 1
    assert_select "input[type=radio][name='student[color]'][value='#{Student.next_color_for(@family)}'][checked]"
  end

  test "the color picker is a radio group of eight named swatches with a check mark each" do
    get new_student_path

    assert_select "fieldset legend", text: "Color"
    assert_select "fieldset input[type=radio][name='student[color]']", 8
    Student::COLORS.each do |color|
      assert_select "label[for='student_color_#{color}']", text: /#{I18n.t("students.colors.#{color}")}/ do
        assert_select "svg"
      end
      assert_select "input#student_color_#{color}[type=radio][value='#{color}']"
    end
  end

  test "the edit form shows the student's values, their color and a Save button" do
    get edit_student_path(@maya)

    assert_select "input#student_name[value='Maya']"
    assert_select "button[type=submit]", text: /Save/
    assert_select "input[type=radio][name='student[color]'][checked]", 1
    assert_select "input[type=radio][name='student[color]'][value='#{@maya.color}'][checked]"
  end

  test "a failed save keeps the submitted color selected and shows the error beside the name" do
    post students_path, params: {student: {name: " ", grade_level: "5th", color: "slate"}}

    assert_response :unprocessable_content
    assert_select "input[type=radio][name='student[color]'][checked]", 1
    assert_select "input[type=radio][name='student[color]'][value='slate'][checked]"
    assert_select "p", text: "Enter a name to continue."
    assert_select "input[name='student[grade_level]'][value='5th'][maxlength='50']"
  end

  test "the forms never hard-code swatch colors" do
    get new_student_path

    assert_no_match(/#[0-9a-fA-F]{6}\b/, response.body[/<fieldset.*<\/fieldset>/m].to_s)
    assert_select "label[for='student_color_sage'] [style*='var(--student-sage)']"
  end
end
