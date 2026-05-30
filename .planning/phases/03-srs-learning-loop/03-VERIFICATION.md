---
phase: 03-srs-learning-loop
verified: 2026-05-30T18:30:00Z
status: human_needed
score: 20/20
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 18/20
  gaps_closed:
    - "인증된 사용자가 덱 상세에서 Browse 모드로 진입할 수 있다 (BROWSE-01) — deck_browse_path 링크 추가됨"
    - "인증된 사용자가 덱 상세에서 /decks/:id/study 학습을 시작할 수 있다 (STUDY-01 entry) — 학습 시작 버튼 추가됨"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "카드 ≥1 덱에서 학습 시작 버튼 클릭 → Turbo Stream next-card swap 확인"
    expected: "페이지 전체 reload 없이 #study-card DOM 요소만 교체됨. 마지막 카드 후 세션 완료 화면 노출."
    why_human: "Turbo Stream DOM swap은 브라우저 렌더링 동작 — grep으로 확인 불가"
  - test: "학습 세션에서 카드 flip 후 키보드 1/2/3/4 키 입력"
    expected: "해당 rating으로 form submit됨 (flip 전 키 입력은 무시됨)"
    why_human: "keydown event 바인딩 동작은 브라우저 런타임 검증 필요"
  - test: "/decks/:id/browse → 셔플 버튼 클릭 → 카드 순서 확인"
    expected: "카드 순서가 랜덤하게 재배열됨. 셔플 중 라벨 표시. CardReview DB row 미생성."
    why_human: "클라이언트 사이드 Stimulus 상태 변경 — grep으로 확인 불가"
  - test: "카드 0장 덱에서 학습 시작 버튼 상태 확인"
    expected: "버튼이 disabled 상태이고 카드를 먼저 추가하세요 메시지가 노출됨"
    why_human: "disabled 속성 및 hint span의 시각적 렌더링 확인 필요"
---

# Phase 03: SRS Learning Loop — Re-Verification Report

**Phase Goal**: 사용자가 덱을 학습할 수 있고, 4단계 평가가 SM-2를 통해 다음 복습 시각을 계산하며, Turbo Stream으로 다음 카드가 즉시 swap된다. Core Value 실현.
**Verified**: 2026-05-30T18:30:00Z
**Status**: human_needed
**Re-verification**: Yes — 갭 해소(03-05) 후 재검증. 이전 상태: gaps_found (18/20)

---

## Re-Verification Summary

| Gap | 이전 상태 | 현재 상태 | 증거 |
|-----|----------|----------|------|
| BROWSE-01: deck show에 browse 링크 없음 | FAILED | VERIFIED | `show.html.erb:34` — `link_to "훑어보기", deck_browse_path(@deck)` 추가됨 |
| STUDY-01: deck show에 학습 시작 버튼 없음 | PARTIAL | VERIFIED | `show.html.erb:33/36` — 카드 있으면 link_to, 없으면 disabled button 추가됨 |

추가 해소 항목 (CR-01, CR-02, WR-01):

| 결함 | 이전 상태 | 현재 상태 | 증거 |
|-----|----------|----------|------|
| CR-01 IDOR: deck 권한이 params 기반 | Critical/Open | Resolved | `controller.rb:18-19` — `@deck = @card.deck` + `authorize @deck, :show?` 무조건 실행 |
| CR-02 MissingTemplate: `render :error` → ActionView 오류 | Critical/Open | Resolved | `controller.rb:36,54` — `render turbo_stream: turbo_stream.replace(...)` 인라인 (2곳 모두) |
| WR-01: `flash.now[:alert]` dead code | Warning/Open | Resolved | grep 0 match 확인 |
| WR-04: `card_review_params` 미사용 메서드 | Warning/Open | Resolved | grep 0 match 확인 |

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SM-2 알고리즘이 카드 평가 시 next_review_at를 계산한다 | VERIFIED | `submit_review_service.rb` — `Flashcards::Sm2Service.call(**current_state, rating:)`, nil coalescing (ease\|\|2.5 등) |
| 2 | CardReview upsert가 `find_or_initialize_by` + `update!` 패턴으로 동작한다 | VERIFIED | `submit_review_service.rb` — `CardReview.find_or_initialize_by(user: @user, card_id: @card_id)` + `card_review.update!` |
| 3 | RecordNotUnique 경합 시 bare retry 없이 안전하게 처리된다 | VERIFIED | `submit_review_service.rb` — `rescue ActiveRecord::RecordNotUnique` → `find_by!` recovery, bare `retry` 없음 확인 |
| 4 | POST /card_reviews 응답이 Turbo Stream으로 다음 카드를 #study-card에 swap한다 | VERIFIED | `create.turbo_stream.erb` — `turbo_stream.replace "study-card"` |
| 5 | 4단계 평가 버튼(다시/어려움/보통/쉬움, rating 1-4)이 카드 하단에 표시된다 | VERIFIED | `_card.html.erb` — 4 buttons with `card_review[rating]` values 1/2/3/4, aria-labels 있음 |
| 6 | 마지막 카드 평가 후 세션 완료 화면이 표시된다 | VERIFIED | `create.turbo_stream.erb` — `@next_card` nil 분기에서 `decks/studies/complete` partial 렌더 |
| 7 | 평가 버튼 더블클릭 시 단일 제출만 처리된다 (D-05 guard) | VERIFIED | `study_session_controller.js` — `btn.disabled = true` on submitRating |
| 8 | 키보드 단축키(1/2/3/4)로 평가 가능하다 (flip 후에만) | VERIFIED | `study_session_controller.js` — `if (!this.flipped) return` + `handleKeydown` |
| 9 | `/study` 글로벌 큐가 personal + official 덱만 포함한다 (club 제외) | VERIFIED | `global_study_queue_query.rb` — `Deck.where(scope: :personal, owner: @user).or(Deck.where(scope: :official))` |
| 10 | CardReview 없는 신규 카드(NULL)도 due 카드로 포함된다 (STUDY-07) | VERIFIED | `global_study_queue_query.rb` — LEFT OUTER JOIN + `card_reviews.id IS NULL OR ...` 조건 |
| 11 | 글로벌 큐가 사용자별로 격리된다 (multi-tenant) | VERIFIED | `join_clause` — `AND card_reviews.user_id = #{sanitized_id}` |
| 12 | CardReviewPolicy가 `record.user == current_user` 조건을 강제한다 (AUTH-03) | VERIFIED | `card_review_policy.rb` — `record.user == current_user` |
| 13 | CardReviewsController가 IDOR 없이 authorize를 무조건 호출한다 (CR-01) | VERIFIED | `card_reviews_controller.rb:18-19` — `@deck = @card.deck` + `authorize @deck, :show?` (조건부 아님) |
| 14 | 비정상 rating(1-4 외) 입력 시 422 Turbo Stream 응답을 반환한다 (CR-02) | VERIFIED | `card_reviews_controller.rb:36` — `render turbo_stream: turbo_stream.replace("study-card", ...)` status: :unprocessable_entity, `render :error` 없음 |
| 15 | Browse 모드가 CardReview를 생성·수정하지 않는다 (BROWSE-04) | VERIFIED | `browses_controller.rb` — DB write 없음; spec에 `not_to change(CardReview, :count)` assertion |
| 16 | Browse 모드가 Fisher-Yates 셔플을 클라이언트 사이드로 제공한다 (BROWSE-05) | VERIFIED | `browse_controller.js` — `fisherYates()` 메서드, `textContent` only (innerHTML 없음) |
| 17 | Browse 모드가 이전/다음 버튼으로 카드 탐색을 제공한다 (BROWSE-03) | VERIFIED | `browse_controller.js` — `prev()`, `next()`, 첫/끝 disabled 처리 |
| 18 | Browse 모드가 카드 flip을 제공한다 (BROWSE-02) | VERIFIED | `browse_controller.js` — `flip()` 메서드, `browses/show.html.erb` |
| 19 | 인증된 사용자가 덱 상세에서 Browse 모드로 진입할 수 있다 (BROWSE-01) | VERIFIED | `show.html.erb:34` — `link_to "훑어보기", deck_browse_path(@deck)` (`@deck.cards.size.positive?` 분기) |
| 20 | 인증된 사용자가 덱 상세에서 `/decks/:id/study` 학습을 시작할 수 있다 + 빈 덱 guard (STUDY-01 + SC#5) | VERIFIED | `show.html.erb:33,36` — 카드 있으면 link_to deck_study_path, 없으면 disabled button + "카드를 먼저 추가하세요" |

**Score**: 20/20 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/services/flashcards/submit_review_service.rb` | SM-2 upsert + RecordNotUnique 처리 | VERIFIED | `find_or_initialize_by` + `update!`, nil coalescing, rescue RecordNotUnique → find_by! |
| `app/queries/flashcards/global_study_queue_query.rb` | personal+official due 카드 쿼리 | VERIFIED | LEFT OUTER JOIN, sanitized user_id, LIMIT 10 |
| `app/controllers/card_reviews_controller.rb` | POST → Turbo Stream, IDOR-free authorize | VERIFIED | `@deck = @card.deck` 무조건, 2x inline turbo_stream.replace, dead code 제거 |
| `app/controllers/study_controller.rb` | /study 글로벌 큐 | VERIFIED | `GlobalStudyQueueQuery.new(user: Current.user).call`, empty → :complete |
| `app/controllers/decks/browses_controller.rb` | GET /decks/:id/browse, as_json 화이트리스트 | VERIFIED | `as_json(only: %i[id front back])`, `authorize @deck, :show?` |
| `app/views/card_reviews/create.turbo_stream.erb` | turbo_stream.replace #study-card | VERIFIED | `turbo_stream.replace "study-card"` with @next_card / complete branch |
| `app/views/decks/studies/_card.html.erb` | 4 rating buttons, data-controller, form | VERIFIED | `data-controller="study-session"`, 4 buttons aria-labeled, card_reviews_path form |
| `app/javascript/controllers/study_session_controller.js` | flip-gate, double-submit guard, keyboard | VERIFIED | `if (!this.flipped) return`, `btn.disabled = true`, keydown handler |
| `app/views/decks/browses/show.html.erb` | data-browse-cards-value JSON 주입 | VERIFIED | `data-browse-cards-value` present, empty deck branch |
| `app/javascript/controllers/browse_controller.js` | fisherYates, textContent only, prev/next | VERIFIED | `static values = { cards: Array }`, `fisherYates()`, no innerHTML |
| `app/views/study/show.html.erb` | #study-card turbo target, 남은 카드 counter | VERIFIED | `#study-card`, `@due_cards.size` counter |
| `app/views/study/complete.html.erb` | 세션 완료, decks_path (Pitfall 6 safe) | VERIFIED | `decks_path` link, no @deck reference |
| `app/views/decks/show.html.erb` | 학습 시작 버튼 + 훑어보기 링크 | VERIFIED | lines 31-39 — deck-actions region with study/browse CTAs + empty-deck guard |
| `spec/services/flashcards/submit_review_service_spec.rb` | SM-2 + upsert 시나리오 | VERIFIED | 파일 존재, 갭 수정 없이 그린 유지 |
| `spec/queries/flashcards/global_study_queue_query_spec.rb` | due/new/multi-tenant/club-exclusion | VERIFIED | 파일 존재, T-03-04 회귀 가드 포함 |
| `spec/requests/card_reviews_spec.rb` | Turbo Stream, 멱등성, IDOR, strict 422 | VERIFIED | 03-05에서 3개 신규 spec 추가 (Spec A IDOR/Spec B regression/Spec C strict 422) |
| `spec/requests/study_spec.rb` | 글로벌 큐 진입, 빈 큐, club 제외 | VERIFIED | 파일 존재 |
| `spec/requests/decks/browses_spec.rb` | 인증, CardReview 미생성, JSON 필드 검증, 진입점 | VERIFIED | 03-05에서 4개 신규 entry-point spec 추가 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/views/decks/show.html.erb` | `deck_study_path(@deck)` | `link_to` (카드 있을 때) | WIRED | show.html.erb:33 — `link_to "학습 시작", deck_study_path(@deck)` |
| `app/views/decks/show.html.erb` | `deck_browse_path(@deck)` | `link_to` (카드 있을 때) | WIRED | show.html.erb:34 — `link_to "훑어보기", deck_browse_path(@deck)` |
| `card_reviews_controller.rb` | `DeckPolicy#show?` | `authorize @deck, :show?` (unconditional, derived from @card.deck) | WIRED | controller.rb:18-19 — CR-01 IDOR fix 확인 |
| `card_reviews_controller.rb` | `Flashcards::SubmitReviewService` | `.call(user:, card_id:, rating:)` | WIRED | service result success?/failure? 분기 |
| `card_reviews_controller.rb` | `create.turbo_stream.erb` | `format.turbo_stream` + `@next_card` | WIRED | `respond_to` block |
| `create.turbo_stream.erb` | `decks/studies/_card.html.erb` | `turbo_stream.replace "study-card"` | WIRED | partial render in replace block |
| `study_controller.rb` | `Flashcards::GlobalStudyQueueQuery` | `.new(user:).call` | WIRED | `@due_cards` assigned |
| `submit_review_service.rb` | `Flashcards::Sm2Service` | `.call(**current_state, rating:)` | WIRED | result fields (ease, interval_days, repetitions) 소비 |
| `browses_controller.rb` | `browse_controller.js` | `data-browse-cards-value` JSON attr | WIRED | `@cards_json` serialized to view, Stimulus reads via `static values` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `study/show.html.erb` | `@due_cards` | `GlobalStudyQueueQuery.new(user: Current.user).call` → DB LEFT OUTER JOIN | Yes | FLOWING |
| `card_reviews/create.turbo_stream.erb` | `@next_card` | `StudyQueueQuery.new(user:, deck:).call` after upsert | Yes | FLOWING |
| `decks/browses/show.html.erb` | `data-browse-cards-value` | `@deck.cards.order(:position, :id).as_json(only: %i[id front back])` | Yes | FLOWING |
| `browse_controller.js` | `this.cardsValue` | JSON from `data-browse-cards-value` attr | Yes | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — 서버 실행 없이 curl 검증 불가. 라우트 존재는 `config/routes.rb` grep으로 확인.

| Route | config/routes.rb 확인 | Status |
|-------|----------------------|--------|
| `POST /card_reviews` | line 46: `resources :card_reviews, only: %i[create]` | WIRED |
| `GET /study` | line 47: `get "/study", to: "study#show", as: :study` | WIRED |
| `GET /decks/:deck_id/browse` | line 43: `resource :browse, only: %i[show], module: :decks` | WIRED |
| `GET /decks/:deck_id/study` | line 42: `resource :study, only: %i[show], module: :decks` | WIRED |

---

### Probe Execution

Phase 3용 probe 스크립트 없음 (`find scripts -path '*/tests/probe-*.sh'` — no match). SKIPPED.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| STUDY-01 | 03-02, 03-03, 03-05 | `/decks/:id/study` SRS 학습 시작 + 진입점 | SATISFIED | `show.html.erb` deck-actions CTA region (03-05 갭 해소) |
| STUDY-02 | 03-01, 03-03 | `/study` 글로벌 큐 학습 | SATISFIED | `StudyController` + `GlobalStudyQueueQuery` |
| STUDY-03 | 03-02 | Turbo Stream next-card swap | SATISFIED | `create.turbo_stream.erb` |
| STUDY-04 | 03-02 | 4단계 평가 버튼 | SATISFIED | `_card.html.erb` 4 buttons rating 1-4 |
| STUDY-05 | 03-02 | 마지막 카드 후 완료 화면 | SATISFIED | `create.turbo_stream.erb` @next_card nil → complete partial |
| STUDY-06 | 03-01 | `next_review_at <= Time.current` 조건 | SATISFIED | `GlobalStudyQueueQuery` WHERE 조건 |
| STUDY-07 | 03-01 | CardReview 없는 신규 카드 포함 | SATISFIED | LEFT OUTER JOIN + IS NULL 조건 |
| AUTH-03 | 03-02 | `CardReviewPolicy` — `record.user == current_user` | SATISFIED | `card_review_policy.rb` |
| TEST-03 | 03-01, 03-02 | SRS 플로우 request spec | SATISFIED | `spec/requests/card_reviews_spec.rb`, `study_spec.rb` |
| BROWSE-01 | 03-04, 03-05 | Browse 모드 진입점 (덱 상세) | SATISFIED | `show.html.erb:34` — `deck_browse_path(@deck)` 링크 (03-05 갭 해소) |
| BROWSE-02 | 03-04 | 카드 flip | SATISFIED | `browse_controller.js` — `flip()` |
| BROWSE-03 | 03-04 | 이전/다음 버튼 탐색 | SATISFIED | `browse_controller.js` — `prev()`, `next()`, boundary disabled |
| BROWSE-04 | 03-04 | CardReview 미생성 | SATISFIED | `browses_controller.rb` — no DB write, spec assertion |
| BROWSE-05 | 03-04 | 카드 셔플 | SATISFIED | `browse_controller.js` — `fisherYates()`, `toggleShuffle()` |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/queries/flashcards/global_study_queue_query.rb` | 12 | `TODO(phase-4): replace with DeckPolicy::Scope` | Info | 명시적 Phase 4 참조 — debt-marker gate 통과 |

- `TBD`, `FIXME`, `XXX` 마커: Phase 3 수정 파일에서 0건
- `flash.now[:alert]` dead code: 0건 (WR-01 해소)
- `card_review_params` dead method: 0건 (WR-04 해소)
- `render :error` action-template lookup: 0건 (CR-02 해소)
- `if params[:card_review][:deck_id].present?` 조건부 deck 권한: 0건 (CR-01 해소)
- stub 패턴 없음 (return null/return {}/return [] 모두 없음)
- innerHTML 없음 (browse/study Stimulus 컨트롤러 모두 textContent 사용)

---

### Human Verification Required

#### 1. Turbo Stream next-card swap 시각 확인

**Test**: 카드 ≥1 덱에서 `/decks/:id`의 "학습 시작" 버튼 클릭 → 학습 세션 진입 → 4단계 버튼 클릭
**Expected**: 페이지 전체 reload 없이 `#study-card` DOM 요소만 교체됨. 마지막 카드 후 "오늘의 학습 완료" 완료 화면 노출.
**Why human**: Turbo Stream DOM swap은 브라우저 렌더링 동작 — grep으로 확인 불가

#### 2. 키보드 단축키 작동 확인

**Test**: 학습 세션에서 카드 front만 보이는 상태에서 키보드 1/2/3/4 입력 → flip 후 같은 키 입력
**Expected**: flip 전 키 입력 무시됨. flip 후 해당 rating으로 form submit됨.
**Why human**: keydown event 바인딩 동작은 브라우저 런타임 검증 필요

#### 3. Browse 모드 셔플 시각 검증

**Test**: `/decks/:id/browse` → 셔플 버튼 클릭 → 카드 순서 확인 → 셔플 재클릭
**Expected**: 카드 순서가 랜덤하게 재배열됨. "셔플 중" 라벨 표시. 원래 순서 복원 가능. CardReview row 미생성.
**Why human**: 클라이언트 사이드 Stimulus 상태 변경 — grep으로 확인 불가

#### 4. 빈 덱 학습 시작 guard (ROADMAP SC#5)

**Test**: 카드 0장 덱의 `/decks/:id` 페이지 → 학습 시작 버튼 상태 확인
**Expected**: 버튼이 disabled 상태로 클릭 불가하고 "카드를 먼저 추가하세요" 힌트 텍스트가 옆에 표시됨.
**Why human**: disabled 속성의 브라우저 렌더링 및 UX 확인 필요

---

### Gaps Summary

갭 없음. 이전 검증(18/20)에서 발견된 2개 갭이 모두 03-05 플랜으로 해소되었다:
- BROWSE-01 (FAILED → VERIFIED): `show.html.erb:34` — `link_to "훑어보기", deck_browse_path(@deck)` 추가
- STUDY-01 (PARTIAL → VERIFIED): `show.html.erb:33,36` — 카드 있으면 link_to, 없으면 disabled button 추가

추가로 CR-01(IDOR), CR-02(MissingTemplate), WR-01(dead flash), WR-04(dead method)도 코드베이스에서 제거 확인됨.

자동화 검증으로 확인 불가한 4개 브라우저 동작 항목이 남아 있어 status는 `human_needed`.

---

_Verified: 2026-05-30T18:30:00Z_
_Verifier: Claude (gsd-verifier) — re-verification after 03-05 gap closure_
