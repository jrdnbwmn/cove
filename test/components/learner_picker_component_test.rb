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
    assert_selector "span.inline-flex.items-center.gap-2", text: "Maya"
    assert_selector "fieldset[aria-describedby]"
  end

  test "disables unselected read-only learners and allows selected ones to be removed" do
    render_inline(LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: [learners(:kept), learners(:read_only)],
      selected_ids: [learners(:kept).id],
      read_only_ids: [learners(:kept).id, learners(:read_only).id],
      label: "Learners"
    ))

    assert_selector "input[value='#{learners(:read_only).id}'][disabled]"
    assert_text "Read-only on Free"
    assert_selector "input[value='#{learners(:kept).id}'][checked]:not([disabled])"
    assert_text "Read-only"
  end

  test "renders the empty and error states" do
    render_inline(LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: [],
      selected_ids: [],
      label: "Learners",
      error: "Casey is read-only on Free, so they can't be added to a class."
    ))

    assert_text "No learners yet."
    assert_selector "a[href='/learners']", text: "Add a learner"
    assert_text "Casey is read-only on Free, so they can't be added to a class."
  end
end
