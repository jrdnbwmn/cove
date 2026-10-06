class Users::TwoFactorController < ApplicationController
  before_action :authenticate_user!

  def show = redirect_to edit_account_password_path

  def backup_codes
  end

  def create_backup_codes
    current_user.generate_otp_backup_codes! unless current_user.otp_backup_codes?
    current_user.set_otp_secret!
    render :backup_codes
  end

  # AIDEV-NOTE: Two-factor has no UI entry point (Cove ships without it for now). The routes stay so it can be re-enabled; setup starts with POST backup_codes, which creates the secret, so verify has nothing to show until then.
  def verify
    redirect_to edit_account_password_path unless current_user.otp_secret.present?
  end

  def create
    if current_user.verify_and_consume_otp!(params[:code])
      current_user.enable_two_factor!
      redirect_to edit_account_password_path, notice: t(".enabled")
    else
      flash.now[:alert] = t("users.sessions.create.incorrect_verification_code")
      render :verify, status: :unprocessable_content
    end
  end

  def destroy
    current_user.disable_two_factor!
    redirect_to edit_account_password_path, status: :see_other, notice: t(".disabled")
  end
end
