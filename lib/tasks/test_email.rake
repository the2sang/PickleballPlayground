namespace :mailer do
  desc "Send a test email to janakena111@naver.com to verify Gmail SMTP configuration"
  task test_email: :environment do
    recipient = TestMailer::TEST_RECIPIENT

    puts "Sending test email to #{recipient}..."
    puts "  SMTP server : smtp.gmail.com:587"
    puts "  SMTP user   : #{ENV["SMTP_USER"].presence || "(not set)"}"
    puts "  From        : #{ENV.fetch("EMAIL_FROM", "no-reply@gmail.com")}"

    abort "ERROR: SMTP_USER is not set. Please configure the environment variable." if ENV["SMTP_USER"].blank?
    abort "ERROR: SMTP_PASS is not set. Please configure the environment variable." if ENV["SMTP_PASS"].blank?

    TestMailer.test_email.deliver_now

    puts "Test email sent successfully to #{recipient}."
  rescue => e
    abort "ERROR: Failed to send test email — #{e.class}: #{e.message}"
  end
end
