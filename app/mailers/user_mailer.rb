# AIDEV-NOTE: Loops owns the body and subject for this notification, so no ERB
# template should render when Action Mailer builds the message.
class UserMailer < ApplicationMailer
  include LoopsTransactional

  def account_created
    user = params[:user]
    data_variables = {
      recipient_email: user.email,
      sign_in_url: new_user_session_url
    }

    mail(
      to: email_address_with_name(user.email, user.name),
      from: email_address_with_name(Jumpstart.config.support_email, Jumpstart.config.application_name),
      reply_to: Jumpstart.config.support_email,
      "X-Loops-Transactional-Id": loops_transactional_id(:account_created),
      "X-Loops-Data-Variables": data_variables.to_json,
      body: ""
    )
  end
end
