module PlanPricingHelper
  def monthly_equivalent(plan)
    monthly_amount = BigDecimal(plan.amount) / 1200
    formatted_amount = format("%.2f", monthly_amount).sub(/\.00\z/, "")

    "$#{formatted_amount}/mo"
  end

  def premium_learner_limit
    return current_account.learner_limit if current_account&.premium?

    Account.default_learner_limit
  end
end
