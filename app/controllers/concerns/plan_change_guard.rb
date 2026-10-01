# Shared by the plan-change edit/update pages and the confirmation page so every entry point blocks the same states.
# Expects the including controller to have set @subscription first.
module PlanChangeGuard
  extend ActiveSupport::Concern

  private

  # AIDEV-NOTE: Hidden plans stay reachable for support, but a family can only switch to a visible plan (or stay on
  # its current one) in its own currency. This mirrors what the change-plan page lists, so a hand-built URL or form
  # can't reach a legacy or support-only price.
  def find_plan_change_target(prefix_id)
    current_plan = @subscription.plan
    return unless current_plan

    Plan.visible.or(Plan.where(id: current_plan.id)).where(currency: current_plan.currency).find_by_prefix_id(prefix_id)
  end

  def ensure_plan_change_available
    if @subscription.on_grace_period?
      redirect_to billing_path, alert: t("billing.subscriptions.plan_change_guard.grace_period")
    elsif !@subscription.active? || @subscription.past_due? || @subscription.unpaid?
      redirect_to billing_path, alert: t("billing.subscriptions.plan_change_guard.unavailable")
    elsif (pending_change = @subscription.pending_plan_change)
      redirect_to billing_path, alert: t("billing.subscriptions.plan_change_guard.pending", date: l(pending_change[:starts_at].to_date, format: :long))
    end
  end
end
