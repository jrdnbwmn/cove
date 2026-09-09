class Users::SignupCompletionsController < ApplicationController
  skip_before_action :require_signup_completion!
  before_action :authenticate_user!
  before_action :redirect_unless_signup_completion_required

  layout "minimal"

  def show
    @user = current_user
    @marketing_opt_in = @user.marketing_subscribed?
  end

  def update
    @user = current_user
    @marketing_opt_in = marketing_opt_in?
    @user.assign_attributes(signup_completion_params)

    if @user.first_name.blank?
      @user.errors.add(:first_name, :blank)
      render :show, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @user.save!
      if @marketing_opt_in
        @user.grant_marketing_consent(source: "registration") || raise(ActiveRecord::RecordInvalid.new(@user))
      end
      @user.update_column(:signup_completion_required, false)
    end

    redirect_to stored_location_for(:user) || root_path
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private

  def redirect_unless_signup_completion_required
    redirect_to root_path unless current_user.signup_completion_required?
  end

  def signup_completion_params
    params.require(:user).permit(:first_name, :last_name)
  end

  def marketing_opt_in?
    params.dig(:user, :marketing_opt_in) == "1"
  end
end
