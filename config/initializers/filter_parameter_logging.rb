# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
# AIDEV-NOTE: Honeybadger's request.filter_keys inherits this list, so fields added here are filtered from both logs and error reports. Add homeschool-domain fields (birthdate, grade, notes, transcript) here when those models land.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :otp_attempt,
  :name,
  :first_name,
  :last_name,
  :current_sign_in_ip,
  :last_sign_in_ip,
  :access_token,
  :access_token_secret,
  :refresh_token
]
