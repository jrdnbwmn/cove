module PlanPricingHelper
  def monthly_equivalent(plan)
    monthly_amount = BigDecimal(plan.amount) / 1200
    formatted_amount = format("%.2f", monthly_amount).sub(/\.00\z/, "")

    "$#{formatted_amount}/mo"
  end

  def pricing_learner_limit
    return current_account.learner_limit if current_account

    Account.default_learner_limit
  end
end
