class LearnerPickerComponent < ViewComponent::Base
  def initialize(name:, learners:, selected_ids:, label:, help: nil, error: nil)
    super()
    @name = name
    @learners = learners
    @selected_ids = selected_ids.map(&:to_s)
    @label = label
    @help = help
    @error = error
    @id_prefix = "learner-picker-#{name.parameterize}"
  end

  def selected?(learner)
    @selected_ids.include?(learner.id.to_s)
  end

  def described_by
    [(@help.present? ? help_id : nil), (@error.present? ? error_id : nil)].compact.join(" ").presence
  end

  def help_id
    "#{@id_prefix}-help"
  end

  def error_id
    "#{@id_prefix}-error"
  end

  def label_html_for(learner)
    helpers.render("learners/name_with_dot", learner: learner)
  end
end
