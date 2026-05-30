---
phase: 03-srs-learning-loop
verified: 2026-05-30T00:00:00Z
status: gaps_found
score: 18/20
overrides_applied: 0
gaps:
  - truth: "인증된 사용자는 덱 상세 또는 학습 진입점에서 Flip browse 모드를 시작할 수 있다 (BROWSE-01)"
    status: failed
    reason: "app/views/decks/show.html.erb에 deck_browse_path 링크가 없다. browse 컨트롤러/뷰/라우트/JS는 모두 구현되어 있으나 deck show 페이지에서 진입 불가."
    artifacts:
      - path: "app/views/decks/show.html.erb"
        issue: "No link to deck_browse_path(@deck) — browse 진입점 없음"
    missing:
      - "app/views/decks/show.html.erb에 deck_browse_path(@deck) '훑어보기' 링크 추가"

  - truth: "인증된 사용자는 /decks/:id/study에서 특정 덱의 due 카드 큐로 SRS 학습을 시작할 수 있다 (STUDY-01 entry point)"
    status: partial
    reason: "deck_study_path 엔드포인트와 컨트롤러는 구현되어 있으나 app/views/decks/show.html.erb에 '학습 시작' 버튼이 없다. 사용자가 URL을 직접 입력해야만 학습 진입 가능."
    artifacts:
      - path: "app/views/decks/show.html.erb"
        issue: "No '학습 시작' button linking to deck_study_path(@deck)"
    missing:
      - "app/views/decks/show.html.erb에 deck_study_path(@deck) '학습 시작' 버튼 추가 (빈 덱이면 disabled + 안내 메시지)"
---

# Phase 03: SRS Learning Loop Verification Report

**Phase Goal**: 사용자가 덱을 학습할 수 있고, 4단계 평가가 SM-2를 통해 다음 복습 시각을 계산하며, Turbo Stream으로 다음 카드가 즉시 swap된다. Core Value 실현.
**Verified**: 2026-05-30
**Status**: gaps_found
**Re-verification**: No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SM-2 알고리즘이 카드 평가 시 next_review_at를 계산한다 | VERIFIED | `Flashcards::Sm2Service` (Phase 1), called from `SubmitReviewService#call` with nil-coalescing for initial values |
| 2 | CardReview upsert가 `find_or_initialize_by` + `update!` 패턴으로 동작한다 | VERIFIED | `submit_review_service.rb` — `CardReview.find_or_initialize_by(user: @user, card_id: @card_id)` + `card_review.update!` |
| 3 | RecordNotUnique 경합 시 bare retry 없이 안전하게 처리된다 | VERIFIED | `rescue ActiveRecord::RecordNotUnique` → `find_by!` recovery 블록, bare `retry` 없음 |
| 4 | POST /card_reviews 응답이 Turbo Stream으로 다음 카드를 #study-card에 swap한다 | VERIFIED | `app/views/card_reviews/create.turbo_stream.erb` — `turbo_stream.replace "study-card"` |
| 5 | 4단계 평가 버튼(다시/어려움/보통/쉬움, rating 1-4)이 카드 하단에 표시된다 | VERIFIED | `app/views/decks/studies/_card.html.erb` — 4 buttons with `card_review[rating]` values 1/2/3/4, aria-labels present |
| 6 | 마지막 카드 평가 후 세션 완료 화면이 표시된다 | VERIFIED | `create.turbo_stream.erb` — `@next_card` nil 분기에서 `decks/studies/complete` partial 렌더 |
| 7 | 평가 버튼 더블클릭 시 단일 제출만 처리된다 (D-05 guard) | VERIFIED | `study_session_controller.js` — `btn.disabled = true` on submit, `if (!this.flipped) return` flip-gate |
| 8 | 키보드 단축키(1/2/3/4)로 평가 가능하다 | VERIFIED | `study_session_controller.js` — `connect()`/`disconnect()` keydown handler |
| 9 | `/study` 글로벌 큐가 personal + official 덱만 포함한다 (club 제외) | VERIFIED | `GlobalStudyQueueQuery` — `Deck.where(scope: :personal, owner: @user).or(Deck.where(scope: :official))`, club 명시적 제외 |
| 10 | CardReview 없는 신규 카드(NULL)도 due 카드로 포함된다 (STUDY-07) | VERIFIED | `GlobalStudyQueueQuery` — LEFT OUTER JOIN + `card_reviews.id IS NULL OR ...` 조건 |
| 11 | 글로벌 큐가 사용자별로 격리된다 (multi-tenant) | VERIFIED | `join_clause` — `AND card_reviews.user_id = #{sanitized_id}`, sanitize_sql_like 패턴 |
| 12 | CardReviewPolicy가 `record.user == current_user` 조건을 강제한다 (AUTH-03) | VERIFIED | `app/policies/card_review_policy.rb` — `record.user == current_user` |
| 13 | CardReviewsController가 authorize를 호출한다 | VERIFIED | `card_reviews_controller.rb` — `authorize @card_review` + `authorize @deck, :show?` |
| 14 | 비정상 rating(1-4 외) 입력 시 422로 응답한다 | VERIFIED | `card_reviews_controller.rb` — `rescue ArgumentError => _e; render status: :unprocessable_entity` |
| 15 | Browse 모드가 CardReview를 생성·수정하지 않는다 (BROWSE-04) | VERIFIED | `Decks::BrowsesController#show` — DB write 없음; spec에 CardReview 미생성 assertion 존재 |
| 16 | Browse 모드가 Fisher-Yates 셔플을 클라이언트 사이드로 제공한다 (BROWSE-05) | VERIFIED | `browse_controller.js` — `fisherYates()` 메서드 존재, `textContent` only (innerHTML 없음) |
| 17 | Browse 모드가 이전/다음 버튼으로 카드 탐색을 제공한다 (BROWSE-03) | VERIFIED | `browse_controller.js` — `prev()`, `next()`, 첫/끝 disabled 처리 |
| 18 | Browse 모드가 카드 flip 애니메이션을 제공한다 (BROWSE-02) | VERIFIED | `browse_controller.js` — `flip()` 메서드 + `app/views/decks/browses/show.html.erb` |
| 19 | 인증된 사용자가 덱 상세에서 Browse 모드로 진입할 수 있다 (BROWSE-01) | FAILED | `app/views/decks/show.html.erb`에 `deck_browse_path` 링크 없음 — 전체 app/views/ 검색 결과 0 match |
| 20 | 인증된 사용자가 덱 상세에서 `/decks/:id/study` 학습을 시작할 수 있다 (STUDY-01 entry) | PARTIAL | `deck_study_path` 엔드포인트 작동하나 `app/views/decks/show.html.erb`에 학습 시작 버튼 없음 |

**Score**: 18/20 truths verified (1 FAILED, 1 PARTIAL)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/services/flashcards/submit_review_service.rb` | SM-2 upsert + RecordNotUnique 처리 | VERIFIED | `find_or_initialize_by` + `update!`, nil coalescing, rescue RecordNotUnique → find_by! recovery |
| `app/queries/flashcards/global_study_queue_query.rb` | personal+official due 카드 쿼리 | VERIFIED | LEFT OUTER JOIN, sanitized user_id param, 10 limit |
| `app/controllers/card_reviews_controller.rb` | POST → Turbo Stream, authorize 2회 | VERIFIED | `authorize @card_review`, `authorize @deck, :show?`, format.turbo_stream |
| `app/controllers/study_controller.rb` | /study 글로벌 큐 | VERIFIED | `GlobalStudyQueueQuery.new(user: Current.user).call`, empty → :complete 분기 |
| `app/controllers/decks/browses_controller.rb` | GET /decks/:id/browse, as_json | VERIFIED | `@cards.as_json(only: %i[id front back])`, `authorize @deck, :show?` |
| `app/views/card_reviews/create.turbo_stream.erb` | turbo_stream.replace #study-card | VERIFIED | `turbo_stream.replace "study-card"` with @next_card / complete branch |
| `app/views/decks/studies/_card.html.erb` | 4 rating buttons, data-controller, form | VERIFIED | 60 lines, `data-controller="study-session"`, 4 buttons aria-labeled |
| `app/javascript/controllers/study_session_controller.js` | flip-gate, double-submit guard, keyboard | VERIFIED | `if (!this.flipped) return`, `btn.disabled = true`, keydown handler |
| `app/views/decks/browses/show.html.erb` | data-browse-cards-value JSON 주입 | VERIFIED | `data-browse-cards-value` present, empty deck branch handled |
| `app/javascript/controllers/browse_controller.js` | fisherYates, textContent only, prev/next | VERIFIED | `static values = { cards: Array }`, `fisherYates()`, no innerHTML |
| `app/views/study/show.html.erb` | #study-card turbo target, 남은 카드 counter | VERIFIED | `#study-card`, `@due_cards.size`장 counter |
| `app/views/study/complete.html.erb` | 세션 완료, decks_path link (Pitfall 6 safe) | VERIFIED | `decks_path` link, no @deck reference |
| `spec/services/flashcards/submit_review_service_spec.rb` | SM-2 + upsert 시나리오 | VERIFIED | File exists (find confirmed) |
| `spec/queries/flashcards/global_study_queue_query_spec.rb` | due/new/multi-tenant/club-exclusion | VERIFIED | File exists (find confirmed) |
| `spec/requests/card_reviews_spec.rb` | Turbo Stream, 멱등성, rating 검증 | VERIFIED | File exists (find confirmed) |
| `spec/requests/study_spec.rb` | 글로벌 큐 진입, 빈 큐 처리 | VERIFIED | File exists (find confirmed) |
| `spec/requests/decks/browses_spec.rb` | 인증, CardReview 미생성, JSON 필드 검증 | VERIFIED | File exists (find confirmed) |
| `app/views/decks/show.html.erb` | 학습 시작 버튼 + 훑어보기 링크 | FAILED | 62 lines — edit/delete buttons, card table, import link 있으나 study/browse 진입점 없음 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `card_reviews_controller.rb` | `Flashcards::SubmitReviewService` | `.call(user:, card_id:, rating:)` | WIRED | service result checked, success?/failure? branch |
| `card_reviews_controller.rb` | `create.turbo_stream.erb` | `format.turbo_stream` + `@next_card` | WIRED | `respond_to` block verified |
| `create.turbo_stream.erb` | `decks/studies/_card.html.erb` | `turbo_stream.replace "study-card"` | WIRED | partial render in replace block |
| `study_controller.rb` | `Flashcards::GlobalStudyQueueQuery` | `.new(user:).call` | WIRED | `@due_cards` assigned and rendered |
| `submit_review_service.rb` | `Flashcards::Sm2Service` | `.call(**current_state, rating:)` | WIRED | result fields (ease, interval_days, repetitions) consumed |
| `decks/browses_controller.rb` | `browse_controller.js` | `data-browse-cards-value` JSON attr | WIRED | `@cards_json` serialized to view, Stimulus reads via `static values` |
| `study_session_controller.js` | `_card.html.erb` DOM | `data-controller="study-session"` | WIRED | outermost div has Pitfall 8 compliant data-controller |
| `decks/show.html.erb` | `deck_study_path` / `deck_browse_path` | link_to / button_to | NOT WIRED | No study or browse entry point links — gap |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `study/show.html.erb` | `@due_cards` | `GlobalStudyQueueQuery.new(user: Current.user).call` → DB LEFT OUTER JOIN | Yes — live DB query | FLOWING |
| `card_reviews/create.turbo_stream.erb` | `@next_card` | `Flashcards::StudyQueueQuery.new(user:, deck:).call` after upsert | Yes — DB query post-submit | FLOWING |
| `decks/browses/show.html.erb` | `data-browse-cards-value` | `@deck.cards.order(:position, :id).as_json(only: %i[id front back])` | Yes — live DB query | FLOWING |
| `browse_controller.js` | `this.cardsValue` | JSON from `data-browse-cards-value` attr | Yes — cards array from server | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — no running server available for curl checks. Route existence verified via `config/routes.rb` grep.

Routes confirmed present in `config/routes.rb`:
- `resources :card_reviews, only: %i[create]` — WIRED
- `get "/study", to: "study#show", as: :study` — WIRED
- `resource :browse, only: %i[show], module: :decks` (inside `resources :decks`) — WIRED
- `resource :study, only: %i[show], module: :decks` — verify needed

---

### Probe Execution

No probe scripts found for Phase 3 (`find scripts -path '*/tests/probe-*.sh'` — no match). SKIPPED.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| STUDY-01 | 03-02, 03-03 | `/decks/:id/study` SRS 학습 시작 | PARTIAL | Endpoint works; no entry point link in decks/show.html.erb |
| STUDY-02 | 03-01, 03-03 | `/study` 글로벌 큐 학습 | SATISFIED | `StudyController` + `GlobalStudyQueueQuery` verified |
| STUDY-03 | 03-02 | Turbo Stream next-card swap | SATISFIED | `create.turbo_stream.erb` — `turbo_stream.replace "study-card"` |
| STUDY-04 | 03-02 | 4단계 평가 버튼 | SATISFIED | `_card.html.erb` — 4 buttons, rating 1-4, aria-labeled |
| STUDY-05 | 03-02 | 마지막 카드 후 완료 화면 | SATISFIED | `create.turbo_stream.erb` `@next_card.nil?` → complete partial |
| STUDY-06 | 03-01 | `next_review_at <= Time.current` 조건 | SATISFIED | `GlobalStudyQueueQuery` — `next_review_at IS NULL OR next_review_at <= ?` |
| STUDY-07 | 03-01 | CardReview 없는 신규 카드 포함 | SATISFIED | LEFT OUTER JOIN + `card_reviews.id IS NULL` 조건 |
| AUTH-03 | 03-02 | `CardReviewPolicy` — `record.user == current_user` | SATISFIED | `app/policies/card_review_policy.rb` verified |
| TEST-03 | 03-01, 03-02 | SRS 플로우 request spec | SATISFIED | `spec/requests/card_reviews_spec.rb`, `spec/requests/study_spec.rb` exist |
| BROWSE-01 | 03-04 | Browse 모드 진입점 (덱 상세) | FAILED | `app/views/decks/show.html.erb` — no `deck_browse_path` link |
| BROWSE-02 | 03-04 | 카드 flip (CSS transform, Stimulus) | SATISFIED | `browse_controller.js` — `flip()` method |
| BROWSE-03 | 03-04 | 이전/다음 버튼 탐색 | SATISFIED | `browse_controller.js` — `prev()`, `next()`, boundary disabled |
| BROWSE-04 | 03-04 | CardReview 미생성 | SATISFIED | `Decks::BrowsesController` — no DB write, spec assertion |
| BROWSE-05 | 03-04 | 카드 셔플 | SATISFIED | `browse_controller.js` — `fisherYates()`, `toggleShuffle()` |

**Orphaned requirements**: AUTH-03 was listed under Phase 1 in REQUIREMENTS.md tracker (line 201) but claimed in 03-02-PLAN.md. `CardReviewPolicy` is a Phase 3 artifact — assignment is correct and verified.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/queries/flashcards/global_study_queue_query.rb` | 12 | `TODO(phase-4): replace with DeckPolicy::Scope` | Info | References explicit future phase — not a blocker per debt-marker gate rules |

No `TBD`, `FIXME`, or `XXX` markers found in any Phase 3 modified files. The single `TODO(phase-4)` marker is a structured forward reference and does not represent unreferenced debt.

No stub patterns detected:
- No `return null` / `return {}` / `return []` in service/controller files
- No `innerHTML` in browse_controller.js or study_session_controller.js
- No hardcoded empty data props in view templates
- No placeholder text in rendered views

---

### Human Verification Required

#### 1. Turbo Stream next-card swap (no full page reload)

**Test**: 카드 5장 있는 개인 덱 → `/decks/:id/study` 진입 → 4단계 버튼 클릭
**Expected**: 페이지 전체 reload 없이 `#study-card` DOM 요소만 교체됨. 마지막 카드 후 "세션 완료" 화면 노출.
**Why human**: Turbo Stream DOM swap은 브라우저 렌더링 동작 — grep으로 확인 불가

#### 2. 키보드 단축키 작동 확인

**Test**: 학습 세션에서 카드 flip 후 키보드 1/2/3/4 키 입력
**Expected**: 해당 rating으로 form submit됨
**Why human**: keydown event 바인딩 동작은 브라우저 런타임 검증 필요

#### 3. Browse 모드 Fisher-Yates 셔플 시각 검증

**Test**: `/decks/:id/browse` → 셔플 버튼 클릭 → 카드 순서 확인
**Expected**: 카드 순서가 랜덤하게 재배열됨. "셔플 중" 라벨 표시. CardReview DB row 미생성.
**Why human**: 클라이언트 사이드 상태 변경 — grep으로 확인 불가

#### 4. 빈 덱 학습 시작 가드 (ROADMAP SC#5)

**Test**: 카드 없는 덱에서 학습 시작 버튼 클릭 시도 (버튼 추가 후)
**Expected**: 버튼이 disabled이거나 "카드를 먼저 추가하세요" 메시지 표시
**Why human**: 현재 entry point 자체가 누락 — UI 구현 후 검증 필요

---

### Gaps Summary

**Root cause**: Phase 3 Wave 2 구현(Plan 02-04)은 browse/study 기능의 컨트롤러, 뷰, 라우트, JS를 모두 구현했으나, `app/views/decks/show.html.erb`에 진입점 링크를 추가하지 않았다. 사용자가 URL을 직접 입력하지 않으면 학습/훑어보기 기능에 접근할 수 없다.

**Scope of gap**: 2개 파일 변경으로 해결 가능한 단순 뷰 누락. 백엔드 로직, 서비스, 쿼리, JS 컨트롤러는 모두 정상 구현됨.

**Impact**:
- BROWSE-01 (FAILED): `deck_browse_path(@deck)` 링크 없음
- STUDY-01 (PARTIAL): `deck_study_path(@deck)` 학습 시작 버튼 없음
- ROADMAP SC#5 ("빈 덱에서 '학습 시작' 버튼 비활성화"): 버튼 자체가 없어 검증 불가

**Fix required**: `app/views/decks/show.html.erb`에 두 링크/버튼 추가:
1. `deck_study_path(@deck)` — "학습 시작" 버튼 (빈 덱이면 disabled)
2. `deck_browse_path(@deck)` — "훑어보기" 링크

---

_Verified: 2026-05-30_
_Verifier: Claude (gsd-verifier)_
