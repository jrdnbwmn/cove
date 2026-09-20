module PricingHelper
  def monthly_equivalent(plan)
    monthly_amount = BigDecimal(plan.amount) / 1200
    formatted_amount = format("%.2f", monthly_amount).sub(/\.00\z/, "")

    "$#{formatted_amount}/mo"
  end

  def premium_student_limit
    return current_account.student_limit if current_account&.premium?

    Account.column_defaults.fetch("student_limit").to_i
  end
end
