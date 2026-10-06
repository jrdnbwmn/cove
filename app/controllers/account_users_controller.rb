class AccountUsersController < Accounts::BaseController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_account_user, only: :destroy
  before_action :require_account_admin

  layout "sidebar"

  def destroy
    unless @account.owner?(current_user) && !@account_user.account_owner?
      redirect_to @account, alert: t("unauthorized")
      return
    end

    ApplicationRecord.transaction do
      user = @account_user.user
      @account_user.destroy!
      user.create_default_account
    end
    redirect_to @account, status: :see_other, notice: t(".destroyed")
  end

  private

  def set_account = @account = current_user.accounts.find(params[:account_id])
  def set_account_user = @account_user = @account.account_users.find(params[:id])
end
