class Users::RegistrationsController < Devise::RegistrationsController
  invisible_captcha only: :create
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_user_registration_path, alert: I18n.t("try_again_later") }

  layout "sidebar", only: [:edit, :update]

  def destroy
    if current_user.must_transfer_family_before_deletion?
      redirect_to edit_user_registration_path, alert: "Transfer family ownership before deleting your login"
    else
      super
    end
  end

  protected

  def build_resource(hash = {})
    self.resource = resource_class.new_with_session(hash, session)

    # Registering to accept an invitation should display the invitation on sign up
    if params[:invite] && (invite = AccountInvitation.find_by(token: params[:invite]))
      @account_invitation = invite

      # Use name/email from the invite if not already provided. Email defaults to "" so it must use a presence check.
      resource.name ||= invite.name
      resource.email = invite.email
      resource.marketing_opt_in = false
      resource.invitation_signup = true
    end
  end

  def update_resource(resource, params)
    # Jumpstart: Allow user to edit their profile without password
    resource.update_without_password(params)
  end

  def sign_up(resource_name, resource)
    super

    refer(resource) if defined? Refer

    if @account_invitation
      @account_invitation.accept!(current_user)

      # Clear redirect to account invitation since it's already been accepted
      stored_location_for(:user)
    end
  end
end
