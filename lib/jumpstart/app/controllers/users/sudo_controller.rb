class Users::SudoController < ApplicationController
  before_action :authenticate_user!
  rate_limit to: 10, within: 3.minutes, only: :create, by: -> { current_user.id }, with: -> { redirect_back fallback_location: root_path, alert: I18n.t("try_again_later") }

  def create
    if current_user.valid_password?(params[:password])
      session[:sudo] = Time.current.to_s
      # Enforce that we stay on the same host
      redirect_to URI.parse(params[:redirect_to]).path
    else
      flash[:alert] = I18n.t("users.sudo.invalid_password")
      render :new, status: :unprocessable_content
    end
  end
end
