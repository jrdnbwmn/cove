class Accounts::AccountInvitationsController < Accounts::BaseController
  before_action :authenticate_user!
  before_action :set_account
  before_action :require_account_admin
  before_action :set_account_invitation, only: [:edit, :update, :destroy, :resend]

  layout "sidebar"

  def new = @account_invitation = AccountInvitation.new

  def create
    if @account.account_users_count + @account.account_invitations.count >= 2
      redirect_to @account, alert: "Family already has two parents"
      return
    end

    if User.by_email(invitation_params[:email]).joins(:accounts).exists?
      redirect_to @account, alert: "That parent already belongs to a family"
      return
    end

    @account_invitation = @account.account_invitations.new(invitation_params.merge(invited_by: current_user, admin: true))
    if @account_invitation.save_and_send_invite
      redirect_to @account, notice: t(".sent", email: @account_invitation.email)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @account_invitation.update(invitation_params.merge(admin: true))
      redirect_to @account, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @account_invitation.destroy
    redirect_to @account, status: :see_other, notice: t(".destroyed")
  end

  def resend
    @account_invitation.send_invite
    redirect_to @account, status: :see_other, notice: t(".sent", email: @account_invitation.email)
  end

  private

  def set_account = @account = current_user.accounts.find(params[:account_id])
  def set_account_invitation = @account_invitation = @account.account_invitations.find_by!(token: params[:id])
  def invitation_params = params.expect(account_invitation: [:name, :email])
end
