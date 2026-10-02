# AIDEV-NOTE: Loops owns the body/subject for these two notifications; the
# vendored Devise ERB views are intentionally unreachable via `body: ""`.
class LoopsDeviseMailer < Devise::Mailer
  include LoopsTransactional

  def reset_password_instructions(record, token, opts = {})
    @token = token
    transactional_id = loops_transactional_id(:reset_password_instructions)
    data_variables = {
      recipient_email: record.email,
      reset_password_url: edit_user_password_url(record, reset_password_token: token)
    }

    devise_mail(record, :reset_password_instructions, opts.merge(
      "X-Loops-Transactional-Id": transactional_id,
      "X-Loops-Data-Variables": data_variables.to_json,
      body: ""
    ))
  end

  def password_change(record, opts = {})
    transactional_id = loops_transactional_id(:password_change)
    data_variables = {recipient_email: record.email}

    devise_mail(record, :password_change, opts.merge(
      "X-Loops-Transactional-Id": transactional_id,
      "X-Loops-Data-Variables": data_variables.to_json,
      body: ""
    ))
  end

  # AIDEV-NOTE: Devise passes the OLD address as opts[:to]; it stays the recipient so the
  # previous owner of the login is warned. record.email is already the new address.
  def email_changed(record, opts = {})
    transactional_id = loops_transactional_id(:email_changed)
    data_variables = {recipient_email: opts[:to] || record.email, new_email: record.email}

    devise_mail(record, :email_changed, opts.merge(
      "X-Loops-Transactional-Id": transactional_id,
      "X-Loops-Data-Variables": data_variables.to_json,
      body: ""
    ))
  end
end
