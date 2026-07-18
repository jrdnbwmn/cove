module PricingHelper
  def pricing_cta(plan)
    # AIDEV-NOTE: Pricing actions now render inside PlanCardComponent, so they cannot rely on the former _plan partial's lazy i18n scope.
    (plan.trial_period_days? && (!user_signed_in? || current_account&.pay_subscriptions&.none?)) ? t("billing.subscriptions.plan.start_trial") : t("billing.subscriptions.plan.get_started")
  end

  def pricing_link_to(plan, **opts)
    default_options = {class: "btn btn-secondary btn-large btn-block"}
    opts = default_options.merge(opts)

    if plan.contact_url.present?
      link_to t("billing.subscriptions.plan.contact_us"), plan.contact_url, **opts
    else
      link_to pricing_cta(plan), checkout_path(plan: plan), **opts
    end
  end
end
