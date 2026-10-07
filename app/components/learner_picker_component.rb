class LearnerPickerComponent < ViewComponent::Base
  def initialize(name:, learners:, selected_ids:, label:, read_only_ids: [], help: nil, error: nil)
    super()
    @name = name
    @learners = learners
    @selected_ids = selected_ids.map(&:to_s)
    @read_only_ids = read_only_ids.map(&:to_s)
    @label = label
    @help = help
    @error = error
    @id_prefix = "learner-picker-#{name.parameterize}"
  end

  def selected?(learner)
    @selected_ids.include?(learner.id.to_s)
  end

  def read_only?(learner)
    @read_only_ids.include?(learner.id.to_s)
  end

  def disabled?(learner)
    read_only?(learner) && !selected?(learner)
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
    identity = helpers.render("learners/name_with_dot", learner: learner)
    badge = helpers.render(BadgeComponent.new(text: I18n.t(selected?(learner) ? "learners.index.read_only_badge" : "learner_picker.read_only_on_free"), size: :sm)) if read_only?(learner)

    helpers.safe_join([identity, badge].compact, " ")
  end
end
