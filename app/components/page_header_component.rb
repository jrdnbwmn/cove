# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base
  renders_one :primary_action
  renders_many :secondary_actions
  renders_one :menu

  alias_method :add_secondary_action, :with_secondary_action

  def with_secondary_action(*args, **kwargs, &block)
    raise ArgumentError, "PageHeaderComponent supports at most two secondary actions" if secondary_actions.size >= 2

    add_secondary_action(*args, **kwargs, &block)
  end

  def initialize(title:, description: nil)
    super()
    @title = title
    @description = description
  end

  def actions?
    primary_action? || secondary_actions.any? || menu?
  end

  def overflow_actions?
    secondary_actions.any? || menu?
  end
end
