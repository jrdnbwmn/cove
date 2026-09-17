class AccountsController < Accounts::BaseController
  before_action :authenticate_user!
  before_action :set_account, only: [:show, :edit, :update, :destroy]
  before_action :require_account_admin, only: [:edit, :update]
  before_action :require_account_owner!, only: :destroy

  layout "sidebar"

  def show
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to @account, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @account.destroy
    redirect_to root_path, status: :see_other, notice: t(".destroyed")
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  end

  def account_params
    attributes = [:name, :avatar]
    attributes << :domain if Jumpstart::Multitenancy.domain?
    attributes << :subdomain if Jumpstart::Multitenancy.subdomain?
    params.expect(account: attributes)
  end

  def require_account_owner!
    redirect_to @account, alert: t("unauthorized") unless @account.owner?(current_user)
  end
end
