# AIDEV-NOTE: Copy of lib/jumpstart/app/controllers/users/connected_accounts_controller.rb, which it replaces entirely
# (Zeitwerk loads one file per constant), so upstream fixes won't reach it. Difference: connected accounts live on the
# Security page, so index and destroy redirect there instead of rendering their own page.
class Users::ConnectedAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_connected_account, only: [:destroy]

  def index
    redirect_to edit_account_password_path
  end

  def destroy
    @connected_account.destroy
    redirect_to edit_account_password_path, status: :see_other
  end

  private

  def set_connected_account
    @connected_account = current_user.connected_accounts.find(params[:id])
  end
end
