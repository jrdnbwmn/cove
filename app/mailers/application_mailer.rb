class ApplicationMailer < ActionMailer::Base
  default from: Jumpstart.config.default_from_email
  layout "mailer"
end
