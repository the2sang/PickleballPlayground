require "test_helper"

class TelegramPromptJobTest < ActiveJob::TestCase
  test "marks a prompt completed and sends the result" do
    prompt = telegram_prompts(:one)

    # notify 메서드는 Telegram API 실패를 rescue해서 job은 항상 완료됨
    TelegramPromptJob.perform_now(prompt)

    prompt.reload
    assert_equal TelegramPrompt::COMPLETED, prompt.status
    assert_includes prompt.result, "개발 작업 요청을 접수했습니다"
  end
end
