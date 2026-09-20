# frozen_string_literal: true

class PlanCardComponent < ViewComponent::Base
  include PlanHelper

  def initialize(plan: nil, name: nil, description: nil, price_text: nil, price_note: nil, features: nil)
    super()
    @plan = plan
    @name = name
    @description = description
    @price_text = price_text
    @price_note = price_note
    @features = features
  end

  private

  attr_reader :plan, :price_text, :price_note

  def name
    @name || plan&.name
  end

  def description
    @description || plan&.description
  end

  def features
    @features || plan&.features || []
  end
end
