class Account::PasswordResetLinksController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to edit_account_password_path, alert: I18n.t("try_again_later") }

  def create
    current_user.send_reset_password_instructions
    redirect_to edit_account_password_path, notice: t(".sent", email: current_user.email)
  end
end
