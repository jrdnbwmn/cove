class Billing::Subscriptions::PlanChangesController < ApplicationController
  include PlanChangeGuard

  before_action :authenticate_user!
  before_action :require_current_account_admin
  before_action :set_subscription
  before_action :ensure_plan_change_available, only: :show
  before_action :set_plan, only: :show
  before_action :ensure_different_plan, only: :show
  before_action :ensure_pending_change, only: :destroy

  layout "minimal", only: :show

  def show
  end

  def destroy
    @subscription.release_schedule!
    redirect_to billing_path, notice: t(".success"), status: :see_other
  rescue Pay::Error => e
    # Stripe's message can include price ids and request ids, so log it and show a fixed message instead.
    Rails.logger.error("[PlanChanges] Could not release schedule for #{@subscription.processor_id}: #{e.message}")
    redirect_to billing_path, alert: t(".failure"), status: :see_other
  end

  private

  def set_subscription
    @subscription = current_account.pay_subscriptions.find_by_prefix_id!(params[:subscription_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to billing_path
  end

  def set_plan
    @plan = find_plan_change_target(params[:plan])
    redirect_to billing_path if @plan.nil?
  end

  def ensure_different_plan
    redirect_to billing_path if @subscription.plan == @plan
  end

  def ensure_pending_change
    redirect_to billing_path unless @subscription.pending_plan_change?
  end
end
