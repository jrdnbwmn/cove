class Billing::SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_current_account_admin, except: [:index, :show]
  before_action :set_plan, only: [:update]
  before_action :set_subscription, only: [:show, :edit, :update]

  def index
    redirect_to billing_url
  end

  def show
    redirect_to edit_subscription_path(@subscription)
  end

  def edit
    # Include current plan even if hidden
    @current_plan = @subscription.plan

    plans = Plan.visible.sorted.or(Plan.where(id: @current_plan.id))
    @monthly_plans, @yearly_plans = plans.partition(&:monthly?)
  end

  def update
    @subscription.swap @plan.id_for_processor(current_account.payment_processor.processor)
    redirect_to billing_path, notice: t(".success")
  rescue Pay::ActionRequired => e
    redirect_to pay.payment_path(e.payment.id)
  rescue Pay::Error => e
    edit # Reload plans
    flash[:alert] = e.message
    render :edit, status: :unprocessable_content
  end

  private

  # Pricing page will only display visible plans, but hidden plans are included here to make customer support easier.
  def set_plan
    @plan = Plan.find_by_prefix_id!(params[:plan])
  rescue ActiveRecord::RecordNotFound
    redirect_to pricing_path
  end

  def set_subscription
    @subscription = current_account.pay_subscriptions.find_by_prefix_id(params[:id])
    redirect_to billing_path if @subscription.nil?
  end
end
