class UiModalComponentPreview < ViewComponent::Preview
  def default
    render UiModalComponent.new(title: "Invite a teammate", trigger_text: "Invite teammate").with_content("Choose a teammate to invite to this project.")
  end

  def large
    render UiModalComponent.new(size: :lg, title: "Project settings", trigger_text: "Open settings").with_content("Settings content appears here.")
  end

  def confirmation
    render UiModalComponent.new(title: "Delete project?", trigger_text: "Delete project", prevent_dismiss: true, show_close_button: false).with_content("This action cannot be undone.")
  end
end
