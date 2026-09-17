class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Jumpstart::Omniauth::Callbacks

  def google_oauth2
    existing_user = User.by_email(auth.info.email).first if auth.info.email.present?

    if !user_signed_in? && connected_account.blank? && existing_user
      if existing_user.connected_accounts.where(provider: auth.provider).exists?
        redirect_to new_user_session_path, alert: t(".account_exists")
      else
        existing_user.connected_accounts.create!(connected_account_params)
        sign_in_and_redirect existing_user, event: :authentication
        success_message!(kind: auth.provider)
      end
    else
      super
    end
  end
end
