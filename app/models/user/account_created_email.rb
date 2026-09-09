module User::AccountCreatedEmail
  extend ActiveSupport::Concern

  included do
    after_create_commit :send_account_created_email
  end

  private

  def send_account_created_email
    UserMailer.with(user: self).account_created.deliver_later
  end
end
