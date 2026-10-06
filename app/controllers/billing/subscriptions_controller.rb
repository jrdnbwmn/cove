# AIDEV-NOTE: Copy of lib/jumpstart/app/controllers/billing/subscriptions_controller.rb. It replaces the Jumpstart
# file entirely (Zeitwerk loads one file per constant), so fixes made to that version in a Jumpstart upgrade won't
# reach this one. Differences: edit renders in the "minimal" layout; index/show are one-line redirects.
class Billing::SubscriptionsController < ApplicationController
  # AIDEV-NOTE: Local change (COV-94) to Jumpstart: guards plan changes and defers yearly -> monthly to renewal.
  include PlanChangeGuard

  before_action :authenticate_user!
  before_action :require_current_account_admin, except: [:index, :show]
  before_action :set_subscription, only: [:show, :edit, :update]
  before_action :set_plan, only: :update
  # AIDEV-NOTE: Local change (COV-94) to Jumpstart: hidden plans are no longer accepted here (see PlanChangeGuard).
  # Runs after set_subscription because the allowed plans depend on the subscription's current plan.
  before_action :ensure_plan_change_available, only: [:edit, :update]

  layout "minimal", only: :edit

  def index = redirect_to billing_url
  def show = redirect_to edit_subscription_path(@subscription)

  def edit
    @current_plan = @subscription.plan
    # AIDEV-NOTE: Local change (COV-97) to Jumpstart: subscriptions for retired Stripe prices may not have a Plan row.
    return redirect_to(billing_path, alert: t("billing.subscriptions.plan_change_guard.unavailable")) unless @current_plan

    # Include current plan even if hidden
    plans = Plan.visible.sorted.or(Plan.where(id: @current_plan.id))
    @monthly_plans, @yearly_plans = plans.partition(&:monthly?)
  end

  def update
    if @subscription.plan_change_at_renewal?(@plan)
      @subscription.schedule_plan_change_at_renewal(@plan)
    else
      @subscription.release_schedule!
      @subscription.swap @plan.id_for_processor(current_account.payment_processor.processor)
    end
    redirect_to billing_path, notice: t(".success")
  rescue Pay::ActionRequired => e
    redirect_to pay.payment_path(e.payment.id)
  rescue Pay::Error => e
    # AIDEV-NOTE: Local change (COV-94) to Jumpstart: Stripe's message can include price and request ids, so log it
    # and show a fixed message instead.
    Rails.logger.error("[Subscriptions] Could not change plan #{@subscription.processor_id}: #{e.message}")
    edit
    flash[:alert] = t(".failure")
    render :edit, status: :unprocessable_content
  end

  private

  def set_plan
    @plan = find_plan_change_target(params[:plan])
    redirect_to pricing_path if @plan.nil?
  end

  def set_subscription
    @subscription = current_account.pay_subscriptions.find_by_prefix_id(params[:id])
    redirect_to billing_path if @subscription.nil?
  end
end
