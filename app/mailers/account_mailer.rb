# AIDEV-NOTE: Loops owns the body/subject for these notifications; the vendored
# account-mailer ERB views are intentionally unreachable via `body: ""`.
class AccountMailer < ApplicationMailer
  include LoopsTransactional

  def invite
    account_invitation = params[:account_invitation]
    inviter = account_invitation.invited_by || User.new(name: "Someone")
    data_variables = {
      inviter_name: inviter.name,
      account_name: account_invitation.account.name,
      invitation_url: account_invitation_url(account_invitation)
    }

    mail(
      to: email_address_with_name(account_invitation.email, account_invitation.name),
      from: email_address_with_name(Jumpstart.config.support_email, Jumpstart.config.application_name),
      "X-Loops-Transactional-Id": loops_transactional_id(:invite),
      "X-Loops-Data-Variables": data_variables.to_json,
      body: ""
    )
  end

  def cancellation_reason
    user = params[:user]

    mail(
      to: email_address_with_name(user.email, user.name),
      from: email_address_with_name(Jumpstart.config.support_email, Jumpstart.config.application_name),
      reply_to: Jumpstart.config.support_email,
      "X-Loops-Transactional-Id": loops_transactional_id(:cancellation_reason),
      "X-Loops-Data-Variables": {}.to_json,
      body: ""
    )
  end
end
