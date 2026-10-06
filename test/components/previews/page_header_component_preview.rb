class PageHeaderComponentPreview < ViewComponent::Preview
  def title_only
    render PageHeaderComponent.new(title: "Students")
  end

  def with_description
    render PageHeaderComponent.new(title: "Students", description: "The people learning with you.")
  end

  def with_actions
    component = PageHeaderComponent.new(title: "Students", description: "The people learning with you.")
    component.with_secondary_action { '<button type="button">Export</button>'.html_safe }
    component.with_secondary_action { '<button type="button">Print</button>'.html_safe }
    component.with_primary_action { '<button type="button">Add student</button>'.html_safe }
    render component
  end

  def with_menu
    component = PageHeaderComponent.new(title: "Students")
    component.with_primary_action { '<button type="button">Add student</button>'.html_safe }
    component.with_menu { '<a href="#">Import students</a>'.html_safe }
    render component
  end
end
