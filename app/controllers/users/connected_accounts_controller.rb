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
