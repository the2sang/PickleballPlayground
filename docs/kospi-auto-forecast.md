# 코스피 자동 전망 등록 시스템

> 작성일: 2026-05-12  
> 상태: 설계 완료, 미구현  
> 목표: 매일 오전 8시 KST, 코스피 주식전망을 StockInfo 페이지에 자동 등록

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│  config/recurring.yml                                    │
│  매일 08:00 KST → FetchKospiForecastJob 실행             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  FetchKospiForecastJob (Solid Queue)                     │
│  1. 주말 체크 → skip                                     │
│  2. 오늘 이미 등록됐으면 → skip (idempotency)            │
│  3. KospiForecast::FetchService.call 호출                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  KospiForecast::FetchService                             │
│  Step 1: NAVER Finance API 호출 (무료, 실시간)           │
│    → 현재가, 등락률, 고가/저가 취득                      │
│  Step 2: Claude API 호출 (anthropic gem)                 │
│    → 실시간 데이터를 컨텍스트로 분석 텍스트 생성         │
│  Step 3: StockInfo.create!                               │
└─────────────────────────────────────────────────────────┘
```

---

## 구현 파일 목록

```
app/
  jobs/
    fetch_kospi_forecast_job.rb          # 신규
  services/
    kospi_forecast/
      fetch_service.rb                   # 신규
      naver_client.rb                    # 신규
config/
  recurring.yml                          # 수정 — 스케줄 추가
Gemfile                                  # 수정 — anthropic gem 추가
```

---

## 구현 순서

1. `gem "anthropic"` Gemfile 추가 → `bundle install`
2. `bin/rails credentials:edit` → `anthropic.api_key` 추가
3. `KospiForecast::NaverClient` 구현
4. `KospiForecast::FetchService` 구현
5. `FetchKospiForecastJob` 구현
6. `config/recurring.yml` 스케줄 등록

---

## 상세 구현 가이드

### 1. Gemfile

```ruby
gem "anthropic"
```

### 2. credentials (bin/rails credentials:edit)

```yaml
anthropic:
  api_key: sk-ant-...
```

### 3. config/recurring.yml 수정

```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  fetch_kospi_forecast:
    class: FetchKospiForecastJob
    queue: default
    schedule: every day at 11pm    # UTC 23:00 = KST 08:00
    # 주의: 서버 타임존이 Asia/Seoul이면 "at 8am every day"로 변경
```

### 4. app/services/kospi_forecast/naver_client.rb

```ruby
module KospiForecast
  class NaverClient
    API_URL = "https://m.stock.naver.com/api/index/KOSPI/price"

    def fetch
      uri = URI(API_URL)
      response = Net::HTTP.get_response(uri)
      raise "NAVER API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data.first  # 오늘 날짜 데이터
    rescue StandardError => e
      Rails.logger.error("NaverClient failed: #{e.message}")
      raise
    end
  end
end
```

### 5. app/services/kospi_forecast/fetch_service.rb

```ruby
module KospiForecast
  class FetchService
    Result = Data.define(:success, :stock_info, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call = new.call

    def call
      market_data = NaverClient.new.fetch
      content = generate_forecast(market_data)

      stock_info = StockInfo.create!(
        query: "코스피 주식전망 #{Date.today}",
        content: content,
        queried_at: Time.current
      )

      Result.new(success: true, stock_info: stock_info, error: nil)
    rescue StandardError => e
      Rails.logger.error("KospiForecast::FetchService failed: #{e.message}")
      Result.new(success: false, stock_info: nil, error: e.message)
    end

    private

      def generate_forecast(data)
        client = Anthropic::Client.new(
          api_key: Rails.application.credentials.dig(:anthropic, :api_key)
        )

        prompt = build_prompt(data)

        message = client.messages(
          model: "claude-sonnet-4-6",
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }]
        )

        message.content.first.text
      end

      def build_prompt(data)
        <<~PROMPT
          오늘(#{Date.today}) 코스피 시장 데이터를 바탕으로 한국어로 오늘의 주식 전망을 작성해줘.

          【오늘 코스피 데이터】
          - 종가: #{data['closePrice']}
          - 전일 대비: #{data['compareToPreviousClosePrice']} (#{data['compareToPreviousPrice']&.dig('text')})
          - 등락률: #{data['fluctuationsRatio']}%
          - 시가: #{data['openPrice']}
          - 고가: #{data['highPrice']}
          - 저가: #{data['lowPrice']}

          다음 형식으로 작성해줘:
          - 오늘 시장 요약 (2-3줄)
          - 주요 특징 (불릿 포인트)
          - 단기 전망 및 주의사항
          - 이모지 활용해서 읽기 쉽게
        PROMPT
      end
  end
end
```

### 6. app/jobs/fetch_kospi_forecast_job.rb

```ruby
class FetchKospiForecastJob < ApplicationJob
  queue_as :default

  def perform
    return if weekend?
    return if already_registered_today?

    result = KospiForecast::FetchService.call

    if result.success?
      Rails.logger.info("KospiForecast registered: ID #{result.stock_info.id}")
      # 선택사항: Telegram으로 등록 완료 알림
      # Telegram::Client.new.send_message(chat_id: ENV["TELEGRAM_ADMIN_CHAT_ID"], text: "✅ 코스피 전망 자동 등록 완료")
    else
      Rails.logger.error("KospiForecast failed: #{result.error}")
      raise result.error  # Solid Queue 재시도 트리거
    end
  end

  private

    def weekend?
      Date.today.saturday? || Date.today.sunday?
    end

    def already_registered_today?
      StockInfo.where("DATE(queried_at) = ?", Date.today).exists?
    end
end
```

---

## 실패 시나리오 대응

| 실패 | 감지 | 대응 |
|------|------|------|
| NAVER API 다운 | HTTP 에러 | raise → Solid Queue 재시도 (3회) |
| Claude API 에러 | 응답 코드 | raise → 재시도 |
| 중복 실행 | `already_registered_today?` | Skip, 로그만 |
| 주말 | `Date.today.saturday?` | Skip |

---

## NOT in scope (이번 구현 제외)

| 항목 | 이유 |
|------|------|
| 공휴일 자동 감지 | 기존 HolidayService 연동 필요, 별도 작업 |
| 코스닥/섹터별 전망 | 범위 초과 |
| Admin UI 수동 트리거 | Rails console로 충분 |
| 전망 품질 자동 평가 | 추후 evals 도입 시 |

---

## 테스트 커버리지 요구사항

구현 시 아래 경로 테스트 필수:

```
FetchKospiForecastJob
  - 주말 → perform 조기 종료
  - 오늘 이미 등록 → perform 조기 종료 (idempotency)
  - 서비스 성공 → StockInfo 1건 생성
  - 서비스 실패 → 예외 발생 (재시도 트리거)

KospiForecast::FetchService
  - NAVER API 정상 → StockInfo 생성 성공
  - NAVER API 실패 → Result.failure? == true
  - Claude API 실패 → Result.failure? == true
```

---

## 참고: NAVER Finance API 응답 예시

```json
[
  {
    "localTradedAt": "2026-05-12",
    "closePrice": "7,618.51",
    "compareToPreviousClosePrice": "-203.73",
    "compareToPreviousPrice": { "code": "5", "text": "하락" },
    "fluctuationsRatio": "-2.60",
    "openPrice": "7,953.41",
    "highPrice": "7,999.67",
    "lowPrice": "7,421.71"
  }
]
```

API URL: `https://m.stock.naver.com/api/index/KOSPI/price`
