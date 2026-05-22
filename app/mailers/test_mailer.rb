class TestMailer < ApplicationMailer
  TEST_RECIPIENT = "janakena111@naver.com"

  def test_email
    mail(
      to: TEST_RECIPIENT,
      subject: "SMTP Test - PickleballPlayground"
    )
  end
end
