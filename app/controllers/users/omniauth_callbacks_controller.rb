class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Jumpstart::Omniauth::Callbacks

  # AIDEV-NOTE: COV-96 removed auto-linking Google to an existing account by email.
  # Local password accounts have unverified emails, so auto-linking let an attacker
  # who pre-registered a victim's email keep a working password on the victim's account.
  # Existing accounts must sign in with their password, then connect Google themselves.
  def google_oauth2
    if !user_signed_in? && connected_account.blank? && auth.info.email.present? && User.by_email(auth.info.email).exists?
      store_location_for(:user, user_connected_accounts_path)
      redirect_to new_user_session_path, alert: t("users.omniauth_callbacks.account_exists")
    else
      super
    end
  end
end
