module PlanPricingHelper
  def monthly_equivalent(plan)
    monthly_amount = BigDecimal(plan.amount) / 1200
    formatted_amount = format("%.2f", monthly_amount).sub(/\.00\z/, "")

    "$#{formatted_amount}/mo"
  end

  def pricing_learner_limit
    current_account&.learner_limit || Account.default_learner_limit
  end

  # The "Unlimited learners" feature line. The asterisk points at the footnote under the
  # cards, so it is hidden from screen readers (the footnote is plain text, not a note marker).
  def pricing_learners_feature
    safe_join([t("pricing.show.learners"), tag.span("*", aria: {hidden: true})])
  end
end
