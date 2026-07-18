# frozen_string_literal: true

class PlanCardComponent < ViewComponent::Base
  include PlanHelper

  def initialize(plan:)
    super()
    @plan = plan
  end

  private

  attr_reader :plan
end
