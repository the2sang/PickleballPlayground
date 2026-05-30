# Phase 3: SRS Learning Loop - Research

**Researched:** 2026-05-30
**Domain:** Rails 8 + Hotwire (Turbo Stream / Stimulus) + SM-2 SRS 학습 루프
**Confidence:** HIGH (기존 코드베이스 직접 검증, 외부 패키지 없음)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 카드 flip 트리거 — 카드 하단 "답 보기" 버튼. 카드 영역 전체 클릭 또는 CSS 3D 애니메이션 아님.
- **D-02:** 평가 버튼(다시/어려움/보통/쉬움) — 카드 바로 아래, 전체 폭 버튼 4개. 답 보기 전 hidden. Turbo Stream 교체 시 초기화 리셋.
- **D-03:** Flip 상태 관리 — `study_session_controller.js`의 `data-flipped` 토글. CSS 클래스로 back 텍스트/버튼 show/hide. 서버 round-trip 없음.
- **D-04:** 키보드 1/2/3/4 — `data-flipped=true`일 때만 평가 트리거 허용.
- **D-05:** 더블클릭 가드 — 평가 버튼 클릭 시 즉시 disabled. Turbo Stream 교체로 자동 해제.
- **D-06:** 서버 stateless 방식 — `POST /card_reviews` → SubmitReviewService → StudyQueueQuery 재실행 → Turbo Stream replace `#study-card`.
- **D-07:** 세션 완료 감지 — 서버가 StudyQueueQuery 재실행 후 empty이면 complete partial을 Turbo Stream으로 replace.
- **D-08:** `deck_id` 컨텍스트 전달 — form의 `hidden_field :deck_id`로 CardReviewsController에 전달.
- **D-09:** `SubmitReviewService` — `Flashcards::SubmitReviewService.call(user:, card_id:, rating:)`. SM-2 호출 + `find_or_initialize_by(user_id:, card_id:)` + `update!` + `rescue ActiveRecord::RecordNotUnique`. 성공 시 `Result.new(success?: true, card_review:)`.
- **D-10:** 실패 시 `status: :unprocessable_entity` + Turbo Stream 에러 메시지.
- **D-11:** Browse — 클라이언트 사이드 전체 로드. 카드 전체를 `data-browse-cards-value` JSON으로 전달. `browse_controller.js`가 인덱스 관리.
- **D-12:** Browse flip — "답 보기" 버튼 (study와 동일 UX). 평가 버튼 없음.
- **D-13:** 셔플 — `browse_controller.js`의 Fisher-Yates 알고리즘. 서버 요청 없음.
- **D-14:** URL — `GET /decks/:id/browse`, `Decks::BrowsesController` 독립 라우트.
- **D-15:** Browse는 CardReview 미생성. 요청 spec으로 강제 검증.
- **D-16:** `StudyController < ApplicationController` (네임스페이스 없음). `get '/study', to: 'study#show'`.
- **D-17:** `GlobalStudyQueueQuery` — `user:`만 받음. 접근 가능 덱 스코프: `Deck.where(scope: :personal, owner: user).or(Deck.where(scope: :official))`. `policy_scope(Deck)` 사용 금지. `# TODO(phase-4)` 마커.
- **D-18:** 글로벌 큐 빈 상태 — "/decks로 이동" 링크.
- **D-19:** `policy_scope(Deck)` 절대 사용 금지 (stub이라 scope.none 반환).
- **D-20:** `front_image`/`back_image` strong params 제외 유지.
- **D-21:** `ApplicationService` 상속 금지 — PORO (`Struct.new`, `Result = Struct.new...`).
- **D-22:** SM-2 quality 매핑 고정. ⚠️ **CONFLICT 주의 — Assumptions Log A1 참조.**
- **D-23:** 이미 작성된 파일 보전 — StudyQueueQuery, StudiesController, studies/ 뷰, studies_spec.rb (5 examples 그린). 완전 재작성 금지, 기능 확장만.

### Claude's Discretion

- Stimulus controller 파일명 (study_session vs study): 프로젝트 컨벤션(`snake_case + _controller.js`) 따라 결정
- Browse 카드 데이터 직렬화 포맷: 컨트롤러 구현 시 결정 (JSON 권장 — Stimulus Value API)
- `SubmitReviewService` Result 구조: `OpenStruct`/`Struct`/`Data.define` — 기존 서비스 패턴 따름

### Deferred Ideas (OUT OF SCOPE)

- Club deck in global study queue → Phase 4
- Due-count badge on nav → Phase 5
- Streak / mastery / today stats → Phase 5
- Tournament event 학습 CTA → Phase 5
- Per-day new card limit 설정 UI → v1은 LIMIT 10 하드코딩
- 키보드 단축키 힌트 UI → Phase 3 범위이나 구현 방식은 Claude 결정
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STUDY-01 | `/decks/:id/study` SRS 학습 — due 카드 큐 진입 | `Decks::StudiesController#show` 골격 존재. `StudyQueueQuery` 완성. 확장만 필요. |
| STUDY-02 | `/study` 글로벌 큐 | `StudyController` 신규 생성. `GlobalStudyQueueQuery` 신규 생성. D-17 스코프 패턴. |
| STUDY-03 | `POST /card_reviews` Turbo Stream next-card swap | `CardReviewsController#create` 신규. `respond_to { format.turbo_stream }` 패턴. `cards/create.turbo_stream.erb` 참고 패턴 존재. |
| STUDY-04 | 4단계 평가 버튼 표시 | `_card.html.erb` 확장. UI-SPEC 컬러 계약 존재. Stimulus `study_session_controller.js` 신규. |
| STUDY-05 | 마지막 카드 평가 → 완료 화면 | D-07: 서버에서 empty 감지 후 complete partial Turbo Stream replace. `complete.html.erb` 존재. |
| STUDY-06 | `next_review_at <= Time.current` due 조건 | `StudyQueueQuery`에 이미 구현됨. KST 타임존 `Time.current` 사용 확인. |
| STUDY-07 | CardReview 없는 카드 = due | `StudyQueueQuery` LEFT OUTER JOIN으로 이미 구현. 스펙 4번째 example이 검증. |
| BROWSE-01 | Flip browse 모드 진입점 | `Decks::BrowsesController#show` 신규. 덱 상세에서 링크 추가. |
| BROWSE-02 | 카드 flip (CSS, Stimulus) | `browse_controller.js` 신규. "답 보기" 버튼 + CSS show/hide 패턴 (3D CSS 아님). |
| BROWSE-03 | 이전/다음 탐색 | `browse_controller.js` 인덱스 관리. prev/next 버튼. |
| BROWSE-04 | CardReview 미생성 | 컨트롤러에 CardReview 관련 코드 없음 + request spec으로 검증. |
| BROWSE-05 | 셔플 옵션 | `browse_controller.js` Fisher-Yates 클라이언트 사이드. |
| TEST-01 | SM-2 서비스 단위 테스트 | Phase 1에서 이미 구현됨 — 이 Phase에서 신규 작성 불필요. |
| TEST-03 | SRS 학습 플로우 request spec | `CardReviewsController` + `StudyController` + `Decks::BrowsesController` request spec 신규. |
| AUTH-03 | CardReviewPolicy `record.user == current_user` | `CardReviewPolicy` 이미 존재. `create?`에 구현됨. |
</phase_requirements>

---

## Summary

Phase 3는 Phase 1~2에서 완성된 기반 위에 SRS 학습 루프의 핵심 사이클을 완성한다. SM-2 서비스, CardReview 모델, StudyQueueQuery, StudiesController 골격이 모두 존재하며 이를 보전·확장하는 방식으로 접근한다. 신규로 작성할 코드는 `SubmitReviewService`, `CardReviewsController`, `GlobalStudyQueueQuery`, `StudyController`, `Decks::BrowsesController`, 두 개의 Stimulus 컨트롤러, 그리고 관련 뷰와 request spec이다.

이 Phase의 핵심 난이도는 Turbo Stream stateless 방식(`POST /card_reviews` → 큐 재실행 → replace #study-card)과 Stimulus의 flip/keyboard/guard 인터랙션 조합이다. 모든 서버 코드는 기존 PORO 서비스 패턴을 따르며, `ApplicationService` 상속 없이 순수 Ruby 객체로 구현한다.

Browse 모드는 완전한 클라이언트 사이드 구현이다. 컨트롤러가 카드 전체를 JSON으로 내려보내면 Stimulus가 이전/다음/셔플을 모두 처리한다. 서버 round-trip 없음, CardReview 생성 없음이 핵심 불변 조건이다.

**Primary recommendation:** 기존 `StudyQueueQuery` + `StudiesController` 패턴을 그대로 따라 새 컴포넌트를 작성한다. Turbo Stream 응답은 `cards/create.turbo_stream.erb` 패턴을 참조한다. 서비스 Result 구조는 `Participations::CreateService`의 `Struct.new(:success?, ...)` 패턴을 사용한다.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SM-2 계산 + CardReview 저장 | API/Backend (SubmitReviewService) | — | 순수 비즈니스 로직. 서버 단독 책임. |
| 다음 카드 큐 조회 (due 판단) | API/Backend (Query Object) | — | DB 쿼리. Time.current(KST) 기준. |
| Turbo Stream #study-card replace | Frontend Server (ERB 렌더) | — | 서버가 HTML fragment 생성 후 전송. |
| 카드 flip 상태 (front/back 토글) | Browser/Client (Stimulus) | — | 서버 round-trip 없는 UI 상태. |
| 키보드 단축키 (1/2/3/4) | Browser/Client (Stimulus) | — | 클라이언트 이벤트 핸들러. |
| 더블클릭 가드 (disabled) | Browser/Client (Stimulus) | — | 즉각적 UI 피드백 필요 → 클라이언트. |
| Browse 카드 탐색 (이전/다음/셔플) | Browser/Client (Stimulus) | — | 전체 카드 JSON 로드 후 인덱스 관리. |
| 인증 (require_authentication) | API/Backend (ApplicationController concern) | — | 모든 액션 before_action으로 강제. |
| Pundit 권한 (authorize) | API/Backend (Policy) | — | CardReviewPolicy, DeckPolicy. |
| 글로벌 큐 덱 스코프 | API/Backend (GlobalStudyQueueQuery) | — | policy_scope 금지 → 명시적 WHERE. |

---

## Standard Stack

### Core (이미 설치됨 — 추가 gem 없음)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails 8.1 | 8.1.x | 웹 프레임워크 | [VERIFIED: codebase] |
| Turbo (hotwire-rails) | ~8.x | Turbo Stream response | [VERIFIED: codebase — Turbo Stream 템플릿 존재] |
| Stimulus | ~3.x | 클라이언트 인터랙션 | [VERIFIED: codebase — controllers/ 존재] |
| Pundit | ~2.x | Authorization | [VERIFIED: codebase — ApplicationController include] |
| RSpec + FactoryBot | ~6.x / ~6.x | 테스트 | [VERIFIED: codebase — 5 specs green] |
| Tailwind CSS 4 | 4.x | 스타일링 | [VERIFIED: CLAUDE.md + UI-SPEC] |

### Supporting (이미 존재하는 패턴)

| Component | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| `Flashcards::Sm2Service` | `app/services/flashcards/sm2_service.rb` | SM-2 계산 | SubmitReviewService 내부에서만 호출 |
| `Flashcards::StudyQueueQuery` | `app/queries/flashcards/study_queue_query.rb` | 덱별 due 큐 | StudiesController, CardReviewsController |
| `Participations::CreateService` | `app/services/participations/create_service.rb` | Result Struct 패턴 참조 | SubmitReviewService 작성 시 모델 |
| `cards/create.turbo_stream.erb` | `app/views/cards/` | Turbo Stream append 패턴 참조 | CardReviews#create Turbo Stream 작성 시 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Stateless 큐 재실행 (D-06) | 세션 내 큐 캐시 | 서버 상태 없음이 단순함. 동시 탭 문제 없음. |
| Stimulus data-flipped toggle | CSS :checked hack | Stimulus이 Rails 표준이며 테스트 가능. |
| JSON via data-attribute (Browse) | 카드별 AJAX | 단일 요청 + 클라이언트 셔플 가능. 카드 수 적음(LIMIT 제한 없음). |

**Installation:** 추가 gem/npm 패키지 없음. 기존 스택으로 완성 가능.

---

## Package Legitimacy Audit

이 Phase는 신규 외부 패키지를 설치하지 않는다. 모든 필요 라이브러리(Hotwire, Stimulus, Pundit, RSpec, FactoryBot)는 Phase 1~2에서 이미 Gemfile/importmap에 등록되어 있다.

**Packages removed due to [SLOP]:** 없음  
**Packages flagged as [SUS]:** 없음  
**slopcheck 실행:** N/A — 신규 패키지 없음

---

## Architecture Patterns

### System Architecture Diagram

```
사용자 브라우저
    │
    ├─ GET /decks/:id/study ──────────────► Decks::StudiesController#show
    │                                           │ authorize @deck, :show?
    │                                           │ StudyQueueQuery.new(user:, deck:).call
    │                                           │ empty? → render :complete
    │                                           └─► render show.html.erb
    │                                                 └─ #study-card → _card.html.erb
    │
    ├─ "답 보기" 클릭 ──────────────────► study_session_controller.js
    │   (클라이언트 사이드)                   data-flipped=true
    │                                          back 표시, 평가 버튼 표시
    │
    ├─ 평가 버튼 클릭 / 키보드 1~4 ──────► study_session_controller.js
    │   (클라이언트 사이드)                   모든 버튼 disabled (더블클릭 가드)
    │                                          form.requestSubmit()
    │
    ├─ POST /card_reviews ───────────────► CardReviewsController#create
    │   {card_id, rating, deck_id}              │ build CardReview (record.user = Current.user)
    │                                           │ authorize @card_review, :create?
    │                                           │ SubmitReviewService.call(user:, card_id:, rating:)
    │                                           │   ├─ Sm2Service.call(ease:, interval_days:, repetitions:, rating:)
    │                                           │   └─ card_review.find_or_initialize_by + update! + rescue RecordNotUnique
    │                                           │ StudyQueueQuery.new(user:, deck:).call → next_card
    │                                           │ empty? → Turbo Stream replace #study-card ← complete partial
    │                                           └─► Turbo Stream replace #study-card ← _card partial
    │
    ├─ GET /study ───────────────────────► StudyController#show
    │                                           │ GlobalStudyQueueQuery.new(user:).call
    │                                           │ empty? → render :complete (global variant)
    │                                           └─► render show.html.erb
    │
    └─ GET /decks/:id/browse ────────────► Decks::BrowsesController#show
                                               │ authorize @deck, :show?
                                               │ @cards = @deck.cards.ordered
                                               └─► render show.html.erb
                                                     data-browse-cards-value: @cards.map{}.to_json
                                                     browse_controller.js 인덱스 관리
```

### Recommended Project Structure

```
app/
  controllers/
    card_reviews_controller.rb          # 신규 — POST /card_reviews
    study_controller.rb                 # 신규 — GET /study (글로벌 큐)
    decks/
      studies_controller.rb            # 기존 — 확장 없이 보전
      browses_controller.rb            # 신규 — GET /decks/:id/browse
  services/
    flashcards/
      sm2_service.rb                   # 기존 — 변경 금지
      submit_review_service.rb         # 신규 — CardReview upsert 오케스트레이터
  queries/
    flashcards/
      study_queue_query.rb             # 기존 — 변경 금지
      global_study_queue_query.rb      # 신규 — 글로벌 큐
  views/
    card_reviews/
      create.turbo_stream.erb          # 신규 — #study-card replace
    study/
      show.html.erb                    # 신규 — 글로벌 큐 학습 화면
      complete.html.erb                # 신규 — 글로벌 큐 완료 화면
    decks/
      studies/
        show.html.erb                  # 기존 — 진행 카운터 추가
        _card.html.erb                 # 기존 확장 — back + 평가 버튼 추가
        complete.html.erb              # 기존 — 보전 (font-bold → font-semibold 수정)
      browses/
        show.html.erb                  # 신규 — Browse 페이지
        _card.html.erb                 # 신규 — Browse 카드 partial
  javascript/controllers/
    study_session_controller.js        # 신규 — flip, keyboard, guard
    browse_controller.js               # 신규 — prev/next/shuffle
spec/
  requests/
    card_reviews_spec.rb               # 신규
    study_spec.rb                      # 신규 (글로벌 큐)
    decks/
      studies_spec.rb                  # 기존 5 examples — 보전
      browses_spec.rb                  # 신규
```

### Pattern 1: Turbo Stream replace #study-card

**What:** `CardReviewsController#create`가 `respond_to { format.turbo_stream }`으로 응답. ERB 템플릿이 `turbo_stream.replace`로 `#study-card` div를 새 카드 partial 또는 complete partial로 교체.

**When to use:** 평가 후 다음 카드 전환, 세션 완료 전환, 에러 표시.

```ruby
# app/controllers/card_reviews_controller.rb
def create
  @card = Card.find(params[:card_review][:card_id])
  @card_review = CardReview.new(user: Current.user, card: @card)
  authorize @card_review

  result = Flashcards::SubmitReviewService.call(
    user: Current.user,
    card_id: params[:card_review][:card_id],
    rating: params[:card_review][:rating].to_i
  )

  @deck = Deck.find(params[:card_review][:deck_id]) if params[:card_review][:deck_id].present?

  if result.success?
    @next_card = @deck ? Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call.first : nil
    respond_to { |f| f.turbo_stream }
  else
    respond_to do |f|
      f.turbo_stream { render :error, status: :unprocessable_entity }
    end
  end
end
```

```erb
<%# app/views/card_reviews/create.turbo_stream.erb %>
<%= turbo_stream.replace "study-card" do %>
  <% if @next_card %>
    <%= render "decks/studies/card", card: @next_card, deck: @deck %>
  <% else %>
    <%= render "decks/studies/complete", deck: @deck %>
  <% end %>
<% end %>
```

### Pattern 2: SubmitReviewService PORO

**What:** `find_or_initialize_by` + `update!` 패턴으로 upsert. `ActiveRecord::RecordNotUnique` rescue로 경쟁 조건 처리.

```ruby
# app/services/flashcards/submit_review_service.rb
module Flashcards
  class SubmitReviewService
    Result = Struct.new(:success?, :card_review, :errors, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(user:, card_id:, rating:)
      @user    = user
      @card_id = card_id
      @rating  = rating
    end

    def call
      card_review = CardReview.find_or_initialize_by(user: @user, card_id: @card_id)
      current_state = {
        ease:          card_review.ease,
        interval_days: card_review.interval_days,
        repetitions:   card_review.repetitions
      }
      sm2_result = Sm2Service.call(**current_state, rating: @rating)

      card_review.update!(
        ease:             sm2_result.ease,
        interval_days:    sm2_result.interval_days,
        repetitions:      sm2_result.repetitions,
        next_review_at:   sm2_result.next_review_at,
        last_reviewed_at: Time.current,
        last_rating:      @rating
      )
      Result.new(success?: true, card_review: card_review, errors: [])
    rescue ActiveRecord::RecordNotUnique
      retry
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, card_review: nil, errors: e.record.errors.full_messages)
    end
  end
end
```

### Pattern 3: GlobalStudyQueueQuery

**What:** `policy_scope` 사용 금지 → 명시적 WHERE 절로 personal + official 덱의 due 카드를 통합 조회.

```ruby
# app/queries/flashcards/global_study_queue_query.rb
module Flashcards
  class GlobalStudyQueueQuery
    NEW_CARD_LIMIT = 10

    def initialize(user:)
      @user = user
    end

    def call
      # TODO(phase-4): replace with DeckPolicy::Scope when 3-tier resolver is implemented
      accessible_decks = Deck.where(scope: :personal, owner: @user)
                             .or(Deck.where(scope: :official))
      Card.where(deck: accessible_decks)
          .joins(join_clause)
          .where("card_reviews.id IS NULL OR card_reviews.next_review_at IS NULL OR card_reviews.next_review_at <= ?", Time.current)
          .order(Arel.sql("card_reviews.next_review_at ASC NULLS FIRST, cards.position ASC, cards.id ASC"))
          .limit(NEW_CARD_LIMIT)
    end

    private

    attr_reader :user

    def join_clause
      sanitized_id = ActiveRecord::Base.connection.quote(user.id)
      "LEFT OUTER JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = #{sanitized_id}"
    end
  end
end
```

### Pattern 4: Stimulus study_session_controller.js

**What:** flip 상태 관리, 키보드 단축키, 더블클릭 가드.

```javascript
// app/javascript/controllers/study_session_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["back", "showButton", "ratingRow", "keyHints", "ratingButton"]

  connect() {
    this.flipped = false
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  flip() {
    this.flipped = true
    this.showButtonTarget.classList.add("hidden")
    this.backTarget.classList.remove("hidden")
    this.ratingRowTarget.classList.remove("hidden")
    if (this.hasKeyHintsTarget) {
      this.keyHintsTarget.classList.remove("hidden")
    }
    this.showButtonTarget.setAttribute("aria-expanded", "true")
  }

  submitRating(event) {
    const rating = event.currentTarget.dataset.rating
    this.ratingButtonTargets.forEach(btn => {
      btn.disabled = true
      btn.setAttribute("aria-disabled", "true")
    })
    // form submission handled by Turbo (form element)
  }

  handleKeydown(event) {
    if (!this.flipped) return
    const map = { "1": 0, "2": 1, "3": 2, "4": 3 }
    const idx = map[event.key]
    if (idx !== undefined) {
      event.preventDefault()
      this.ratingButtonTargets[idx]?.click()
    }
  }
}
```

### Pattern 5: browse_controller.js (Stimulus Value API)

```javascript
// app/javascript/controllers/browse_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { cards: Array }
  static targets = ["front", "back", "showButton", "counter", "prevButton", "nextButton"]

  connect() {
    this.currentIndex = 0
    this.shuffled = false
    this.orderedCards = [...this.cardsValue]
    this.displayCards = [...this.orderedCards]
    this.render()
  }

  flip() {
    this.showButtonTarget.classList.add("hidden")
    this.backTarget.classList.remove("hidden")
  }

  prev() {
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.render()
    }
  }

  next() {
    if (this.currentIndex < this.displayCards.length - 1) {
      this.currentIndex++
      this.render()
    }
  }

  toggleShuffle() {
    this.shuffled = !this.shuffled
    if (this.shuffled) {
      this.displayCards = this.fisherYates([...this.orderedCards])
    } else {
      this.displayCards = [...this.orderedCards]
    }
    this.currentIndex = 0
    this.render()
  }

  render() {
    const card = this.displayCards[this.currentIndex]
    if (!card) return
    this.frontTarget.textContent = card.front
    this.backTarget.textContent = card.back
    this.backTarget.classList.add("hidden")
    this.showButtonTarget.classList.remove("hidden")
    this.counterTarget.textContent = `${this.currentIndex + 1} / 전체 ${this.displayCards.length}`
    this.prevButtonTarget.disabled = this.currentIndex === 0
    this.nextButtonTarget.disabled = this.currentIndex === this.displayCards.length - 1
  }

  fisherYates(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]]
    }
    return arr
  }
}
```

### Anti-Patterns to Avoid

- **`policy_scope(Deck)` 사용:** Phase 1 stub이 `scope.none` 반환 → 큐 전체 비어버림. 명시적 WHERE 사용.
- **CardReview 저장을 callback으로:** `after_create` 대신 서비스 명시 호출.
- **complete.html.erb 재작성:** D-23 lock — 기존 파일 보전. `font-bold` → `font-semibold`만 수정.
- **SubmitReviewService에서 ApplicationService 상속:** D-21 금지. PORO만.
- **Browse 모드에서 CardReview 생성:** D-15 금지.
- **키보드 단축키를 flip 전에 허용:** D-04 — `data-flipped=true` 체크 필수.
- **GlobalStudyQueueQuery에서 Club 덱 포함:** Phase 4까지 deferred. personal + official만.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SM-2 알고리즘 | 커스텀 간격 계산 | `Flashcards::Sm2Service` (Phase 1) | 이미 완성·테스트됨. 변경 금지. |
| Due 카드 조회 | 인라인 WHERE 조건 | `Flashcards::StudyQueueQuery` (기존) | 5 specs green. N+1 없는 LEFT JOIN 최적화. |
| Turbo Stream replace | 직접 JS DOM 조작 | `turbo_stream.replace` ERB helper | Rails 표준. Stimulus과 자동 통합. |
| PORO Result 구조 | OpenStruct (느림) | `Struct.new(:success?, :card_review, :errors, keyword_init: true)` | `Participations::CreateService` 기존 패턴. |
| Fisher-Yates 셔플 | 자체 구현 | `browse_controller.js` 내 구현 (3줄) | 클라이언트 표준 알고리즘. 외부 라이브러리 불필요. |

**Key insight:** Phase 3의 신규 코드 대부분은 연결(glue)이다. SM-2 계산, 큐 조회, 인증, Turbo Stream — 모두 기존 구현 존재. 재발명하지 말고 연결만 할 것.

---

## Common Pitfalls

### Pitfall 1: ActiveRecord::RecordNotUnique 미처리
**What goes wrong:** 두 탭에서 동일 카드 동시 평가 시 `(user_id, card_id)` unique 제약 위반으로 500 에러.
**Why it happens:** `build` + `save` 대신 `find_or_initialize_by` 사용하지 않거나 rescue 없음.
**How to avoid:** `find_or_initialize_by(user_id:, card_id:)` + `update!` + `rescue ActiveRecord::RecordNotUnique` → retry.
**Warning signs:** 테스트에서 동시 요청 없이 통과 → 운영에서만 발생.

### Pitfall 2: policy_scope(Deck) 호출
**What goes wrong:** `DeckPolicy::Scope#resolve`가 `scope.none` 반환(Phase 1 stub) → 큐 항상 비어 있음.
**Why it happens:** 자동으로 떠오르는 Rails 패턴이지만 Phase 3에서 의도적으로 금지됨.
**How to avoid:** D-19 준수. `Deck.where(scope: :personal, owner: user).or(...)` 명시적 스코프.
**Warning signs:** study 화면이 항상 "오늘의 학습 완료"로 표시됨.

### Pitfall 3: flip 전 키보드 단축키 동작
**What goes wrong:** 사용자가 카드를 보기 전에 1~4 키를 누르면 의도치 않은 평가가 저장됨.
**Why it happens:** keydown 리스너가 `data-flipped` 상태를 확인하지 않음.
**How to avoid:** D-04 — `if (!this.flipped) return` 가드 최우선 확인.
**Warning signs:** 키보드 테스트 중 flip 없이 평가가 제출됨.

### Pitfall 4: Turbo Stream 응답 후 버튼 re-enable 시도
**What goes wrong:** 서버 응답 후 JS로 버튼 disabled를 해제하려 하면 DOM 교체와 타이밍 충돌.
**Why it happens:** Turbo Stream replace가 DOM 전체를 교체하므로 수동 해제 불필요.
**How to avoid:** D-05 — 새 카드 partial은 항상 초기 상태(버튼 enabled)로 렌더. 수동 re-enable 코드 작성 금지.

### Pitfall 5: Browse에서 CardReview 생성
**What goes wrong:** BROWSE-04 요구사항 위반. 진도 오염.
**Why it happens:** CardReview 생성 로직을 controller concern이나 callback으로 추가하면 browse에도 적용될 수 있음.
**How to avoid:** `Decks::BrowsesController`에는 `SubmitReviewService` 호출 코드 절대 없음. Request spec으로 강제: `POST` 요청이 CardReview를 생성하지 않는지 검증.

### Pitfall 6: complete.html.erb의 `@deck` nil 참조 (글로벌 큐)
**What goes wrong:** `StudyController`에서 complete 렌더 시 `@deck`이 nil → `deck_path(@deck)` NoMethodError.
**Why it happens:** 덱별 complete.html.erb을 글로벌 큐 컨텍스트에서 그대로 재사용.
**How to avoid:** D-18 — 글로벌 큐 전용 `study/complete.html.erb` 작성. `@deck` 없으므로 `/decks` 링크 사용.

### Pitfall 7: SubmitReviewService 초기 CardReview 기본값
**What goes wrong:** 신규 카드(CardReview 없음)를 평가할 때 `find_or_initialize_by`로 빌드된 record의 `ease`가 2.5(기본값)이 아닌 nil이면 SM-2 계산 오류.
**Why it happens:** `CardReview` 모델의 DB 기본값(`ease: 2.5`, `interval_days: 0`, `repetitions: 0`)이 `find_or_initialize_by`로 초기화된 record에 반영되지 않을 수 있음.
**How to avoid:** `Sm2Service.call`에 전달 전 기본값 확인: `ease: card_review.ease || 2.5`, `interval_days: card_review.interval_days || 0`, `repetitions: card_review.repetitions || 0`. 또는 모델 `after_initialize`로 기본값 보장.

### Pitfall 8: Stimulus 컨트롤러 Turbo Stream 이후 connect() 미호출
**What goes wrong:** Turbo Stream이 `#study-card`를 replace하면 새 DOM에 `data-controller`가 있어도 Stimulus이 연결되지 않을 수 있음.
**Why it happens:** Turbo Stream은 기본적으로 `MutationObserver`로 Stimulus를 재연결함. 그러나 카드 partial이 올바른 `data-controller` 속성을 포함하지 않으면 연결 안됨.
**How to avoid:** `_card.html.erb`의 최외곽 div에 `data-controller="study-session"`을 포함시킬 것. 또는 `show.html.erb`의 `#study-card` 외부 wrapper에 controller 마운트.

---

## Code Examples

### Verified Pattern: Turbo Stream replace (기존 코드 참조)

```erb
<%# 기존: app/views/cards/create.turbo_stream.erb — [VERIFIED: codebase] %>
<%= turbo_stream.append "deck-cards-#{@deck.id}" do %>
  <%= render "decks/card_row", card: @card, deck: @deck %>
<% end %>
<%= turbo_stream.replace "deck-add-form-#{@deck.id}" do %>
  <%= render "decks/card_add_form", deck: @deck, card: Card.new %>
<% end %>

<%# Phase 3 패턴 — replace로 #study-card 전체 교체 %>
<%= turbo_stream.replace "study-card" do %>
  <%= render "decks/studies/card", card: @next_card, deck: @deck %>
<% end %>
```

### Verified Pattern: SM-2 서비스 호출 시그니처

```ruby
# [VERIFIED: app/services/flashcards/sm2_service.rb]
# 호출 방법 — 모든 파라미터 keyword args
result = Flashcards::Sm2Service.call(
  ease: 2.5,
  interval_days: 0,
  repetitions: 0,
  rating: 3           # 1~4 정수
)
# result.ease, result.interval_days, result.repetitions, result.next_review_at
```

### Verified Pattern: authenticate 패턴

```ruby
# [VERIFIED: app/controllers/concerns/authentication.rb]
# ApplicationController에 include Authentication → 모든 action에 require_authentication 자동 적용
# Current.user = Current.session&.user
# 컨트롤러에서 직접 resume_session 호출 필요 없음 (인증 전용 public action에만 적용)
```

### Verified Pattern: Deck 권한 확인 (StudyController 글로벌 큐 — authorize 없이)

```ruby
# [VERIFIED: D-17 + DeckPolicy 코드]
# StudyController는 Deck 단위 authorize 없이 명시적 스코프로 접근 제어
# authorize nil, :study? 형태도 불가 — GlobalStudyQueueQuery 자체가 접근 제어를 담당
# Pundit의 verify_authorized를 만족시키기 위해 skip_authorization 또는 custom 처리 필요
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CSS 3D flip animation | "답 보기" 버튼 클릭 + CSS show/hide | D-01 결정 | 모바일/데스크탑 동일 UX, 접근성 우수 |
| 세션 내 큐 캐시 | 서버 stateless 큐 재실행 | D-06 결정 | 동시 탭 안전, 서버 상태 없음 |
| DeckPolicy::Scope | 명시적 WHERE (Phase 3) → DeckPolicy::Scope (Phase 4) | D-17 결정 | Phase 4 TODO 마커 필수 |
| ApplicationService 상속 | PORO Struct 패턴 | D-21 결정 | `Participations::CreateService` 패턴 일치 |

**Deprecated/outdated in this codebase:**
- `policy_scope(Deck)`: Phase 3에서 금지. Phase 4에서 재구현 예정.
- CSS 3D transform for card flip: UI-SPEC에서 명시적으로 제외됨.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | **SM-2 QUALITY_MAP** — `app/services/flashcards/sm2_service.rb:14`의 실제 코드는 `{1=>1, 2=>3, 3=>4, 4=>5}`이나 CONTEXT.md D-22는 `{1=>0, 2=>2, 3=>3, 4=>5}`로 기재. 코드가 Phase 1에서 "LOCKED" 마커로 이미 확정됨. **코드 값이 소스 오브 트루스.** D-22 문서는 stale. 플래너와 구현자는 코드 값을 사용하고, CONTEXT.md D-22 수정이 필요한지 사용자에게 확인 요청. | Standard Stack / Pattern 2 | CONTEXT.md D-22가 실제 의도된 값이라면 SM-2 서비스 재수정 필요 — 이미 테스트된 값과 충돌. |
| A2 | `Decks::StudiesController`에 `before_action :resume_session`이 없음. 기존 코드는 `ApplicationController` → `Authentication` concern의 `require_authentication`에 의존. `resume_session`은 CONTEXT.md의 "Established Patterns"에서 언급되었으나 StudiesController에는 실제 없음. 인증은 `require_authentication` before_action으로 처리됨. | Architecture Patterns | 인증 패턴 오해 시 이중 before_action 추가. 실제로는 불필요. |
| A3 | `StudyController#show`에서 Pundit `authorize` 호출 대상 없음. 글로벌 큐는 특정 리소스를 authorize하지 않음. `skip_authorization` 또는 `authorize :application, :study?` 형태 필요. Pundit의 `verify_authorized` after_action이 ApplicationController에 있는지 확인 필요 (현재 미확인). | Architecture Patterns | `verify_authorized` after_action이 있으면 authorize 누락으로 오류. |

---

## Open Questions

1. **StudyController Pundit `verify_authorized` 처리**
   - What we know: `ApplicationController`에 `after_action :verify_authorized` 호출 없음 (코드 확인됨)
   - What's unclear: 그러나 Pundit gem의 default 동작이 Rails 버전에 따라 다를 수 있음
   - Recommendation: `StudyController`에서 `skip_authorization` 명시 or `authorize :application, :study?` 패턴 사용. ApplicationPolicy에 study? 추가.

2. **CONTEXT.md D-22 SM-2 quality mapping 재확인**
   - What we know: 코드는 `{1=>1, 2=>3, 3=>4, 4=>5}`, 문서는 `{1=>0, 2=>2, 3=>3, 4=>5}`
   - What's unclear: 어느 것이 최종 의도인지 (코드가 우선순위이나 문서 드리프트 여부 확인 필요)
   - Recommendation: 사용자에게 확인 요청. 코드 변경 없이 진행. CONTEXT.md D-22를 실제 코드값으로 업데이트.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby 3.3 | Rails 8.1 | ✓ | 3.3.11 (Homebrew) | — |
| Rails 8.1 | 프레임워크 | ✓ | 8.1.x | — |
| SQLite3 | DB | ✓ | — | — |
| Turbo/Stimulus | Hotwire | ✓ | importmap 등록됨 | — |
| Tailwind CSS 4 | 스타일링 | ✓ | 4.x | — |
| RSpec + FactoryBot | 테스트 | ✓ | 6.x | — |
| slopcheck | 패키지 감사 | N/A | — | N/A — 신규 패키지 없음 |

**Missing dependencies with no fallback:** 없음  
**Missing dependencies with fallback:** 없음

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | RSpec |
| Config file | `spec/rails_helper.rb`, `spec/spec_helper.rb` |
| Quick run command | `bundle exec rspec spec/requests/decks/studies_spec.rb` |
| Full suite command | `bundle exec rspec` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STUDY-01 | `/decks/:id/study` 학습 화면 | request | `bundle exec rspec spec/requests/decks/studies_spec.rb` | ✅ (5 examples) |
| STUDY-02 | `/study` 글로벌 큐 | request | `bundle exec rspec spec/requests/study_spec.rb` | ❌ Wave 0 |
| STUDY-03 | POST /card_reviews Turbo Stream | request | `bundle exec rspec spec/requests/card_reviews_spec.rb` | ❌ Wave 0 |
| STUDY-04 | 4단계 평가 버튼 표시 | view/request | `bundle exec rspec spec/requests/decks/studies_spec.rb` | 기존 파일 확장 |
| STUDY-05 | 마지막 카드 → 완료 화면 | request | `bundle exec rspec spec/requests/card_reviews_spec.rb` | ❌ Wave 0 |
| STUDY-06 | due 조건 | unit (query) | `bundle exec rspec spec/queries/` | ❌ Wave 0 |
| STUDY-07 | 신규 카드 = due | request | 기존 studies_spec.rb 4번째 example | ✅ |
| BROWSE-01 | Browse 진입 | request | `bundle exec rspec spec/requests/decks/browses_spec.rb` | ❌ Wave 0 |
| BROWSE-02 | flip (Stimulus) | manual/system | — | manual-only (JS) |
| BROWSE-03 | 이전/다음 탐색 | manual/system | — | manual-only (JS) |
| BROWSE-04 | CardReview 미생성 | request | `bundle exec rspec spec/requests/decks/browses_spec.rb` | ❌ Wave 0 |
| BROWSE-05 | 셔플 (Fisher-Yates) | manual/system | — | manual-only (JS) |
| AUTH-03 | CardReviewPolicy create? | request | `bundle exec rspec spec/requests/card_reviews_spec.rb` | ❌ Wave 0 |
| TEST-03 | SRS 학습 플로우 통합 | request | `bundle exec rspec spec/requests/card_reviews_spec.rb` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bundle exec rspec spec/requests/decks/studies_spec.rb` (기존 5 examples 그린 유지)
- **Per wave merge:** `bundle exec rspec spec/requests/ spec/queries/`
- **Phase gate:** `bundle exec rspec` (전체 suite 그린) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `spec/requests/card_reviews_spec.rb` — POST /card_reviews Turbo Stream, 인증, 실패 케이스
- [ ] `spec/requests/study_spec.rb` — GET /study 글로벌 큐, 빈 상태
- [ ] `spec/requests/decks/browses_spec.rb` — GET /decks/:id/browse, CardReview 미생성 검증
- [ ] `spec/queries/flashcards/global_study_queue_query_spec.rb` — personal + official 스코프, club 제외 검증

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `require_authentication` before_action (Authentication concern) |
| V3 Session Management | no | 기존 Session 모델 변경 없음 |
| V4 Access Control | yes | Pundit: `authorize @card_review` (CardReviewPolicy), `authorize @deck, :show?` |
| V5 Input Validation | yes | strong parameters + `last_rating validates in: 1..4` |
| V6 Cryptography | no | 이 Phase에서 암호화 없음 |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 타인 CardReview 접근 | Elevation | `CardReviewPolicy#create?`: `record.user == user` |
| 비인증 학습 접근 | Unauthorized | `require_authentication` before_action |
| rating 범위 외 입력 | Tampering | `.to_i` 후 CardReview validates `in: 1..4` + SM2Service VALID_RATINGS 검증 |
| deck_id 위조 | Tampering | `Deck.find(deck_id)` + `authorize @deck, :show?` (DeckPolicy) |
| Club deck 글로벌 큐 접근 | Elevation | GlobalStudyQueueQuery가 personal + official만 포함. Club 완전 제외. |

---

## Sources

### Primary (HIGH confidence)

- `app/services/flashcards/sm2_service.rb` — SM-2 서비스 시그니처, QUALITY_MAP 실제 값
- `app/queries/flashcards/study_queue_query.rb` — 덱별 쿼리 패턴 (LEFT JOIN, NULLS FIRST)
- `app/controllers/decks/studies_controller.rb` — 기존 골격 구조
- `app/views/decks/studies/` — 기존 뷰 파일 (_card, complete, show)
- `spec/requests/decks/studies_spec.rb` — 기존 5 examples (green)
- `spec/factories/card_reviews.rb` — factory traits (:due, :mature)
- `app/policies/card_review_policy.rb` — create? 구현
- `app/policies/deck_policy.rb` — show? 구현 + Scope stub
- `app/controllers/concerns/authentication.rb` — require_authentication 패턴
- `app/views/cards/create.turbo_stream.erb` — Turbo Stream 패턴 참조
- `app/services/participations/create_service.rb` — Result Struct 패턴
- `db/schema.rb` — CardReview 컬럼, 인덱스 확인
- `.planning/phases/03-srs-learning-loop/03-CONTEXT.md` — 잠긴 결정 전체
- `.planning/phases/03-srs-learning-loop/03-UI-SPEC.md` — UI 계약

### Secondary (MEDIUM confidence)

- `.planning/REQUIREMENTS.md` — STUDY-01~07, BROWSE-01~05 traceability
- `.planning/STATE.md` — 누적 결정
- `.claude/rules/` — 코딩 컨벤션

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — 모든 라이브러리 codebase에서 직접 확인
- Architecture: HIGH — 기존 코드 패턴 직접 검증, 결정 잠김
- Pitfalls: HIGH — CONTEXT.md 명시 결정 기반 + 실제 코드 상태 확인
- Stimulus 패턴: MEDIUM — Hotwire 표준 패턴이나 기존 study 전용 컨트롤러 없음

**Research date:** 2026-05-30  
**Valid until:** 2026-06-30 (안정 스택, Phase 내부 변경 없으면 유효)
