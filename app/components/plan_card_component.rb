# frozen_string_literal: true

class PlanCardComponent < ViewComponent::Base
  include PlanHelper

  renders_one :actions

  def initialize(plan:)
    super()
    @plan = plan
  end

  private

  attr_reader :plan
end
