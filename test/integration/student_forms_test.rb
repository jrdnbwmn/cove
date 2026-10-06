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

  test "a rejected add at the family limit shows the limit message and keeps what was typed" do
    post students_path, params: {student: {name: "Nora", grade_level: "5th"}}

    assert_response :unprocessable_content
    assert_select "form#student-form h3", text: /Free includes 2 students\. Upgrade to Premium to add more\./
    assert_select "input#student_name[value='Nora']"
    assert_select "input#student_grade_level[value='5th']"
  end

  test "the add form offers the next color pre-selected and an Add student button" do
    get new_student_path

    assert_select "button[type=submit][form='student-form']", text: /Add student/
    assert_select "input[type=radio][name='student[color]'][checked]", 1
    assert_select "input[type=radio][name='student[color]'][value='#{Student.next_color_for(@family)}'][checked]"
  end

  test "the add form puts Cancel then the main action on the right and has no archive or delete" do
    get new_student_path

    assert_select "form#student-form button[type=submit]", count: 0
    assert_select "button[type=submit][form='student-form']", text: /Add student/
    assert_select "button[data-action='click->ui-modal#close:prevent']", text: /Cancel/
    assert_select "form[action$='/archive']", count: 0
    assert_select "a[href*='/delete']", count: 0
    assert_actions_in_order ["Cancel", "Add student"]
  end

  test "the edit form puts Delete on the left and Cancel, Archive, Save on the right" do
    get edit_student_path(@maya)

    assert_select "a[href='#{delete_student_path(@maya)}']", text: "Delete"
    assert_select "button[type=submit][form='student-form']", text: /Save/
    assert_select "button[data-action='click->ui-modal#close:prevent']", text: /Cancel/
    assert_actions_in_order ["Delete", "Cancel", "Archive", "Save"]
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
    assert_select "button[type=submit][form='student-form']", text: /Save/
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
    assert_select "label[for='student_color_sage'] span.student-color[data-student-color='sage']"
    assert_select "span.student-color[style]", count: 0
  end

  private

  # The action row's controls read left to right in DOM order.
  def assert_actions_in_order(labels)
    selector = "[data-student-actions] > a, [data-student-actions] > div > button, [data-student-actions] > div > form button"
    texts = css_select(selector).map { |node| node.text.squish.sub(/ Working\.\.\.\z/, "") }
    assert_equal labels, texts
  end
end
