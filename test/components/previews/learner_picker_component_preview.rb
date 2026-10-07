class LearnerPickerComponentPreview < ViewComponent::Preview
  def default
    render LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: learners,
      selected_ids: [learners.first.id],
      label: "Learners",
      help: "Choose who takes this class. You can leave it empty."
    )
  end

  def read_only
    render LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: learners,
      selected_ids: [learners.first.id],
      read_only_ids: learners.first(2).map(&:id),
      label: "Learners"
    )
  end

  def empty
    render LearnerPickerComponent.new(name: "course[learner_ids][]", learners: [], selected_ids: [], label: "Learners")
  end

  def error
    render LearnerPickerComponent.new(
      name: "course[learner_ids][]",
      learners: learners,
      selected_ids: [],
      label: "Learners",
      error: "Casey is read-only on Free, so they can't be added to a class."
    )
  end

  private

  def learners
    @learners ||= [
      Learner.new(id: 1, name: "Maya", color: "sage"),
      Learner.new(id: 2, name: "Theo", color: "sea"),
      Learner.new(id: 3, name: "Iris", color: "sky")
    ]
  end
end
