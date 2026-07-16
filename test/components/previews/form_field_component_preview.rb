class FormFieldComponentPreview < ViewComponent::Preview
  def default
    render_field(label: "Display name", name: "profile[display_name]")
  end

  def helper_text
    render_field(label: "Display name", name: "profile[display_name]", helper_text: "Shown to collaborators.")
  end

  def error
    render_field(label: "Email", name: "user[email]", error: "Email is invalid.", input_class: "form-control error")
  end

  def disabled
    render_field(label: "Account ID", name: "account[id]", disabled: true, input_attributes: {disabled: true})
  end

  def required
    render_field(label: "Project name", name: "project[name]", required: true)
  end

  def small
    render_field(label: "Small", name: "small", size: :sm)
  end

  def medium
    render_field(label: "Medium", name: "medium", size: :md)
  end

  def large
    render_field(label: "Large", name: "large", size: :lg)
  end

  def floating
    render_field(label: "Floating", name: "floating", variant: :floating)
  end

  def inline
    render_field(label: "Inline", name: "inline", variant: :inline)
  end

  private

  def render_field(label:, name:, input_class: "form-control", input_attributes: {}, **options)
    render FormFieldComponent.new(label: label, name: name, **options) do |component|
      component.with_input do
        ActionController::Base.helpers.tag.input(type: "text", class: input_class, name: name, id: name.to_s.gsub(/[\[\]]/, "_").gsub(/_+$/, ""), **input_attributes)
      end
    end
  end
end
