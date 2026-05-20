class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("EMAIL_FROM", "no-reply@gmail.com")
  layout "mailer"
end
