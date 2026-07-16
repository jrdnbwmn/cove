class PasswordComponentPreview < ViewComponent::Preview
  def default
    render PasswordComponent.new(name: "user[password]", hint: "Use at least 8 characters.")
  end

  def requirements
    render PasswordComponent.new(name: "user[password]", show_strength: true, show_requirements: true)
  end

  def error
    render PasswordComponent.new(name: "user[password]", error: "Password is too short.")
  end

  def disabled
    render PasswordComponent.new(name: "user[password]", disabled: true)
  end
end
