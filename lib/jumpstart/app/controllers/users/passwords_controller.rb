class Users::PasswordsController < Devise::PasswordsController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_user_session_path, alert: I18n.t("try_again_later") }

  # AIDEV-NOTE: Local change (COV-96) to Jumpstart: a signed-in user must be able to open
  # the emailed "set a password" link (Settings → Password). Devise's default
  # require_no_authentication would bounce them with "already signed in". Only edit/update
  # are opened up; the "forgot your password" request form stays signed-out only.
  skip_before_action :require_no_authentication, only: [:edit, :update]

  # TODO: Remove if this PR gets merged https://github.com/heartcombo/devise/pull/5653
  # This allows using a proc for the setting in devise.rb
  def sign_in_after_reset_password?
    setting = resource_class.sign_in_after_reset_password
    setting.respond_to?(:call) ? setting.call(resource) : setting
  end
end
