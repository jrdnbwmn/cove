require "test_helper"
require "view_component/test_case"

class LearnerPickerComponentTest < ViewComponent::TestCase
  test "renders a labelled learner fieldset with selected learners and a clearing value" do
    render_inline(LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: [learners(:one), learners(:two)],
      selected_ids: [learners(:one).id],
      label: "Learners",
      help: "Choose who takes this class."
    ))

    assert_selector "fieldset legend", text: "Learners"
    assert_selector "input[type='hidden'][name='course[learner_ids][]'][value='']", visible: :all
    assert_selector "input[type='checkbox'][name='course[learner_ids][]'][value='#{learners(:one).id}'][checked]"
    assert_selector "input[type='checkbox'][value='#{learners(:two).id}']:not([checked])"
    assert_selector "[data-learner-color='sage']"
    assert_selector "label", text: learners(:one).name
    assert_selector "fieldset[aria-describedby]"
  end

  test "all learners on Free remain selectable after downgrade" do
    render_inline(LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: [learners(:downgraded_one), learners(:downgraded_three)],
      selected_ids: [learners(:downgraded_one).id],
      label: "Learners"
    ))

    assert_selector "input[value='#{learners(:downgraded_three).id}']:not([checked]):not([disabled])"
    assert_selector "input[value='#{learners(:downgraded_one).id}'][checked]:not([disabled])"
    assert_no_selector "input[type='checkbox'][disabled]"
    assert_no_text "Read-only"
  end

  test "the picker no longer accepts plan-based learner restrictions" do
    assert_raises ArgumentError do
      LearnerPickerComponent.new(
        name: "course[learner_ids][]",
        learners: [learners(:downgraded_three)],
        selected_ids: [],
        read_only_ids: [learners(:downgraded_three).id],
        label: "Learners"
      )
    end
  end

  test "renders the empty and error states" do
    render_inline(LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: [],
      selected_ids: [],
      label: "Learners",
      error: "Maya is already in this class."
    ))

    assert_text "No learners yet."
    assert_selector "a[href='/learners']", text: "Add a learner"
    assert_text "Maya is already in this class."
  end
end
