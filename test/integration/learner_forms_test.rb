require "test_helper"

class LearnerFormsTest < ActionDispatch::IntegrationTest
  setup do
    @family = accounts(:company)
    @maya = learners(:one)
    sign_in users(:one)
  end

  test "the add form has a labelled name and optional fixed grade select" do
    get new_learner_path

    assert_select "label[for='learner_name']", text: /Name/
    assert_select "input#learner_name[name='learner[name]'][maxlength='50'][autofocus]"
    assert_select "label[for='learner_grade_level']", text: /Grade level/
    assert_select "select#learner_grade_level[name='learner[grade_level]']"
  end

  test "add and edit offer canonical grades followed by No grade level" do
    expected = ["Pre-K", "Kindergarten", "1st grade", "2nd grade", "3rd grade", "4th grade", "5th grade", "6th grade", "7th grade", "8th grade", "9th grade", "10th grade", "11th grade", "12th grade", "No grade level"]
    [new_learner_path, edit_learner_path(@maya)].each do |path|
      get path
      assert_equal expected, css_select("#learner_grade_level option").map(&:text)
      assert_select "#learner_grade_level[data-select-clear-button-value='false'][data-select-allow-empty-option-value='true']"
      assert_select "#learner_grade_level[data-select-allow-new-value]", count: 0
    end
    assert_select "#learner_grade_level option[selected][value='3rd grade']"
    get new_learner_path
    assert_select "#learner_grade_level option[selected][value='']", text: "No grade level"
  end

  test "a rejected add at the family limit shows the limit message and keeps what was typed" do
    13.times { |i| Learner.create!(account: @family, name: "Learner #{i}") }
    post learners_path, params: {learner: {name: "Nora", grade_level: "5th grade"}}

    assert_response :unprocessable_content
    assert_select "form#learner-form h3", text: "To add more than 15 learners, send us a quick note and we'll raise your limit."
    assert_select "input#learner_name[value='Nora']"
    assert_select "select#learner_grade_level option[selected][value='5th grade']"
  end

  test "the add form offers the next color pre-selected and an Add learner button" do
    get new_learner_path

    assert_select "button[type=submit][form='learner-form']", text: /Add learner/
    assert_select "input[type=radio][name='learner[color]'][checked]", 1
    assert_select "input[type=radio][name='learner[color]'][value='#{Learner.next_color_for(@family)}'][checked]"
  end

  test "the add form puts Cancel then the main action on the right and has no archive or delete" do
    get new_learner_path

    assert_select "form#learner-form button[type=submit]", count: 0
    assert_select "button[type=submit][form='learner-form']", text: /Add learner/
    assert_select "button[data-action='click->ui-modal#close:prevent']", text: /Cancel/
    assert_select "form[action$='/archive']", count: 0
    assert_select "a[href*='/delete']", count: 0
    assert_actions_in_order ["Cancel", "Add learner"]
  end

  test "the edit form puts Delete on the left and Cancel, Archive, Save on the right" do
    get edit_learner_path(@maya)

    assert_select "a[href='#{delete_learner_path(@maya)}']", text: "Delete"
    assert_select "button[type=submit][form='learner-form']", text: /Save/
    assert_select "button[data-action='click->ui-modal#close:prevent']", text: /Cancel/
    assert_actions_in_order ["Delete", "Cancel", "Archive", "Save"]
  end

  test "the color picker is a radio group of eight named swatches with a check mark each" do
    get new_learner_path

    assert_select "fieldset legend", text: "Color"
    assert_select "fieldset input[type=radio][name='learner[color]']", 8
    Learner::COLORS.each do |color|
      assert_select "label[for='learner_color_#{color}']", text: /#{I18n.t("learners.colors.#{color}")}/ do
        assert_select "svg"
      end
      assert_select "input#learner_color_#{color}[type=radio][value='#{color}']"
    end
  end

  test "the edit form shows the learner's values, their color and a Save button" do
    get edit_learner_path(@maya)

    assert_select "input#learner_name[value='Maya']"
    assert_select "button[type=submit][form='learner-form']", text: /Save/
    assert_select "input[type=radio][name='learner[color]'][checked]", 1
    assert_select "input[type=radio][name='learner[color]'][value='#{@maya.color}'][checked]"
  end

  test "a failed save keeps the submitted color selected and shows the error beside the name" do
    post learners_path, params: {learner: {name: " ", grade_level: "5th grade", color: "slate"}}

    assert_response :unprocessable_content
    assert_select "input[type=radio][name='learner[color]'][checked]", 1
    assert_select "input[type=radio][name='learner[color]'][value='slate'][checked]"
    assert_select "p", text: "Enter a name to continue."
    assert_select "select[name='learner[grade_level]'] option[selected][value='5th grade']"
  end

  test "the forms never hard-code swatch colors" do
    get new_learner_path

    assert_no_match(/#[0-9a-fA-F]{6}\b/, response.body[/<fieldset.*<\/fieldset>/m].to_s)
    assert_select "label[for='learner_color_sage'] span.learner-color[data-learner-color='sage']"
    assert_select "span.learner-color[style]", count: 0
  end

  private

  # The action row's controls read left to right in DOM order.
  def assert_actions_in_order(labels)
    selector = "[data-learner-actions] > a, [data-learner-actions] > div > button, [data-learner-actions] > div > form button"
    texts = css_select(selector).map { |node| node.text.squish.sub(/ Working\.\.\.\z/, "") }
    assert_equal labels, texts
  end
end
