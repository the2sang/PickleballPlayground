class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("RESEND_FROM_EMAIL", ENV.fetch("EMAIL_FROM", "onboarding@resend.dev"))
  layout "mailer"
end
