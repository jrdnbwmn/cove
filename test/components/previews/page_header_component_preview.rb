class PageHeaderComponentPreview < ViewComponent::Preview
  def title_only
    render PageHeaderComponent.new(title: "Learners")
  end

  def with_description
    render PageHeaderComponent.new(title: "Learners", description: "The people learning with you.")
  end

  def with_actions
    component = PageHeaderComponent.new(title: "Learners", description: "The people learning with you.")
    component.with_secondary_action { '<button type="button">Export</button>'.html_safe }
    component.with_secondary_action { '<button type="button">Print</button>'.html_safe }
    component.with_primary_action { '<button type="button">Add learner</button>'.html_safe }
    render component
  end

  def with_menu
    component = PageHeaderComponent.new(title: "Learners")
    component.with_primary_action { '<button type="button">Add learner</button>'.html_safe }
    component.with_menu { '<a href="#">Import learners</a>'.html_safe }
    render component
  end
end
