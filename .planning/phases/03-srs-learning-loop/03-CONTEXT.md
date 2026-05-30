# Phase 3: SRS Learning Loop - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

SRS 학습 루프 완성 — 카드 평가(1~4) → SubmitReviewService → SM-2 계산 → CardReview upsert → Turbo Stream으로 다음 카드 swap. Core Value 직결.

포함:
- `GET /decks/:id/study` (Decks::StudiesController) — 덱별 SRS 학습 (골격 이미 작성됨)
- `POST /card_reviews` (CardReviewsController) — 평가 처리 + Turbo Stream 다음 카드
- `GET /study` (StudyController) — 글로벌 큐 (personal + official 통합)
- `GET /decks/:id/browse` (Decks::BrowsesController) — flip browse 모드
- `study_session_controller.js` — Stimulus (flip, 더블클릭 가드, 키보드 1/2/3/4)
- `browse_controller.js` — Stimulus (이전/다음/셔플 클라이언트 사이드)
- `GlobalStudyQueueQuery`, `SubmitReviewService`

제외 (Phase 4+):
- club deck 접근 in global queue → Phase 4
- DeckPolicy::Scope 전면 교체 → Phase 4
- streak / due-count badge / mastery → Phase 5
- 토너먼트 학습 CTA → Phase 5

</domain>

<decisions>
## Implementation Decisions

### 카드 Flip + 평가 버튼 UX

- **D-01:** 답 보기 트리거 — 카드 하단 **"답 보기" 버튼** 클릭. 카드 영역 전체 클릭이나 CSS 3D animation 아님. 모바일/데스크탑 동일 UX.
- **D-02:** 평가 버튼(다시/어려움/보통/쉬움) 위치 — 카드 바로 아래, **전체 폭 버튼 4개**. 답 보기 전에는 `display: none` (DOM에서 완전 숨김 또는 hidden). Turbo Stream으로 카드 교체 시 평가 버튼도 초기화 상태로 리셋.
- **D-03:** Flip 상태 관리 — `study_session_controller.js`가 `data-flipped` 토글. CSS 클래스로 back 텍스트 show/hide, 평가 버튼 show/hide. 서버 round-trip 없음.
- **D-04:** 키보드 단축키 1/2/3/4 — `study_session_controller.js`의 keydown 리스너. `data-flipped=true`일 때만 평가 트리거 허용 (답 보기 전 키보드 실수 방지).
- **D-05:** 더블클릭 가드 — 평가 버튼 클릭 시 버튼 즉시 disabled. Turbo Stream 응답 후 새 카드 교체 시 자동으로 리셋됨.

### Turbo Stream 다음 카드 전략

- **D-06:** 서버 stateless 방식 — `POST /card_reviews` → `SubmitReviewService` 호출 → `StudyQueueQuery.new(user:, deck:).call` 재실행 → 첫 번째 카드를 `Turbo Stream` `replace #study-card`로 내려보냄.
- **D-07:** 세션 완료 감지 — 서버가 `StudyQueueQuery` 재실행 후 결과가 empty이면 complete partial을 Turbo Stream으로 `#study-card`에 replace (complete.html.erb 재활용).
- **D-08:** `deck_id` 컨텍스트 전달 — form의 `hidden_field :deck_id`로 `CardReviewsController`에 전달. `deck_id` → Deck.find → StudyQueueQuery에 전달. (Phase 5에서 글로벌 큐 context는 deck_id 없이 처리.)
- **D-09:** `SubmitReviewService` — `Flashcards::SubmitReviewService.call(user:, card_id:, rating:)`. SM-2 서비스 호출 + `find_or_initialize_by(user_id:, card_id:)` + `update!` + `rescue ActiveRecord::RecordNotUnique`. 성공 시 `Result.new(success?: true, card_review:)` 반환.
- **D-10:** Turbo Stream 실패 응답 — CardReview 저장 실패 시 `status: :unprocessable_entity` + Turbo Stream으로 에러 메시지 렌더.

### Browse Mode

- **D-11:** 네비게이션 방식 — **클라이언트 사이드 전체 로드**. `Decks::BrowsesController#show`에서 카드 전체를 JSON 직렬화해서 `data-browse-cards-value`(Stimulus Value)로 view에 전달. `browse_controller.js`가 현재 인덱스 관리, 이전/다음 버튼으로 카드 swap. 서버 round-trip 없음.
- **D-12:** Browse flip — "답 보기" 버튼 (study와 동일 UX 패턴). 평가 버튼 없음, `browse_controller.js`가 flip 담당.
- **D-13:** 셔플 — 페이지 상단 토글 버튼. `browse_controller.js`가 Fisher-Yates 알고리즘으로 카드 배열 셔플 (클라이언트 사이드). 서버 요청 없음.
- **D-14:** URL — `GET /decks/:id/browse`, `Decks::BrowsesController` 독립 라우트. 브라우저 뒤로가기 가능.
- **D-15:** Browse는 CardReview 미생성 — 컨트롤러/서비스에서 CardReview를 생성·수정하지 않음. 요청 spec으로 강제 검증.

### 글로벌 StudyController

- **D-16:** `StudyController < ApplicationController` (네임스페이스 없음). `get '/study', to: 'study#show'`.
- **D-17:** `GlobalStudyQueueQuery` 별도 클래스 (`user:`만 받음). 접근 가능 덱 스코프: `Deck.where(scope: :personal, owner: user).or(Deck.where(scope: :official))`. `policy_scope(Deck)` 사용 금지. Phase 4에서 DeckPolicy::Scope로 교체 시 `# TODO(phase-4)` 마커 남김.
- **D-18:** 글로벌 큐 빈 상태 — 덱별 `complete` 뷰 동일 패턴. 단, `@deck`이 없으므로 "덱으로 돌아가기" 대신 "/decks로 이동" 링크.

### 기존 코드 보전 (Phase 2 Carryforward 계속)

- **D-19:** `policy_scope(Deck)` 절대 사용 금지 (이미 `scope.none` stub) → 모든 컨트롤러에서 명시적 스코프 사용.
- **D-20:** `front_image`/`back_image` strong params 제외 유지.
- **D-21:** `ApplicationService` 상속 금지 — `SubmitReviewService`도 PORO (`Struct.new`, `Result = Struct.new...`).
- **D-22:** SM-2 quality 매핑 고정: `{1 => 0, 2 => 2, 3 => 3, 4 => 5}`. `Flashcards::Sm2Service.call(state, rating)` — Phase 1에서 확정, 변경 불가.
- **D-23:** 이미 작성된 파일 보전 — `app/queries/flashcards/study_queue_query.rb`, `app/controllers/decks/studies_controller.rb`, `app/views/decks/studies/`, `spec/requests/decks/studies_spec.rb` (5 examples 그린). 완전 재작성 금지, 기능 확장만.

### Claude's Discretion

- Stimulus controller 파일명 (study_session vs study): 플래너가 프로젝트 컨벤션(snake_case + `_controller.js`) 따라 결정
- Browse 카드 데이터 직렬화 포맷 (JSON vs data-attributes): 컨트롤러 구현 시 결정
- `SubmitReviewService` Result 구조: `OpenStruct`/`Struct`/`Data.define` — 기존 서비스 패턴 따름

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 프로젝트 기반

- `.planning/PROJECT.md` — Active 요구사항 전체 + Core Value 정의
- `.planning/REQUIREMENTS.md` — STUDY-01~07, BROWSE-01~05, AUTH-03, SM2-01~06
- `.planning/ROADMAP.md` (Phase 3 섹션) — 성공 기준 7개 + suggested test surface
- `.planning/STATE.md` — 누적 결정 (SM-2 quality mapping, KST 타임존 등)

### Phase 1~2 결과물 (이미 구현된 인터페이스)

- `.planning/phases/01-foundations/01-01-PLAN.md` — SM-2 서비스, CardReview 모델, 정책 stub 인터페이스
- `.planning/phases/01-foundations/01-01-SUMMARY.md` — Phase 1 deliverables 실제 결과
- `.planning/phases/02-deck-card-crud/02-CONTEXT.md` — Carryforward 결정 (policy_scope 금지, 이미지 숨김 등)

### ADR

- `docs/adr/0001-flashcard-cardreview-shared-cards.md` — Card 공유 + CardReview cascade 룰

### 이미 작성된 Phase 3 코드 (researcher가 반드시 읽을 것)

- `app/queries/flashcards/study_queue_query.rb` — 덱별 큐 (deck: 파라미터, LEFT JOIN, due+new)
- `app/controllers/decks/studies_controller.rb` — 덱별 학습 show action
- `app/views/decks/studies/show.html.erb` — `#study-card` Turbo target
- `app/views/decks/studies/_card.html.erb` — 확장 필요 (front만 있음, back+버튼 추가 필요)
- `app/views/decks/studies/complete.html.erb` — 완료 화면
- `spec/requests/decks/studies_spec.rb` — 5 examples (그린 유지 필수)

### 코딩 표준

- `.claude/rules/principles.md` — KISS, YAGNI, Skinny Everything
- `.claude/rules/cli.md` — 테스트/린트 커맨드
- `.claude/rules/anti-patterns.md` — God Model, Callback Spaghetti 금지
- `.claude/rules/queries.md` — Query Object 컨벤션

### 기존 Stimulus 패턴 (참고)

- `app/javascript/controllers/paste_import_controller.js` — 동적 폼 패턴
- `app/javascript/controllers/import_form_controller.js` — requestSubmit() 패턴

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Flashcards::StudyQueueQuery` — 덱별 큐. `GlobalStudyQueueQuery` 작성 시 동일 LIMIT/정렬 로직 참고.
- `app/views/decks/studies/complete.html.erb` — 세션 완료 화면. 글로벌 큐에서는 `@deck` 없으므로 deck_path 링크 제거/변경.
- `Flashcards::Sm2Service` — Phase 1 구현됨. `Sm2Service.call(state, rating)` → `{ ease:, interval_days:, repetitions:, next_review_at: }`.
- `CardReview` model — `validates :last_rating, in: 1..4`. `find_or_initialize_by(user_id:, card_id:)` 패턴.

### Established Patterns

- Turbo Stream 응답: `respond_to { |f| f.turbo_stream }` — `app/views/cards/create.turbo_stream.erb` 참고.
- Stimulus Value API (`data-*-value` + `static values = { cards: Array }`) — 클라이언트 사이드 데이터 바인딩.
- Service Result struct: `app/services/participations/create_service.rb` — `Result = Struct.new(:success?, ...)`.
- `before_action :resume_session` — 모든 authenticated controller.

### Integration Points

- `config/routes.rb` — `resource :study, module: :decks` 이미 추가됨. `resources :card_reviews, only: :create` + `get '/study'` + `resource :browse, module: :decks` 추가 필요.
- `#study-card` — show.html.erb의 Turbo Stream replace target.
- `Flashcards::Sm2Service` — SubmitReviewService에서 직접 호출.

</code_context>

<specifics>
## Specific Ideas

- 더블클릭 가드: 평가 버튼 클릭 즉시 `disabled` 속성 추가, Turbo Stream 교체로 자동 해제 (서버 응답 후 새 DOM).
- `GlobalStudyQueueQuery`는 Phase 4에서 `DeckPolicy::Scope`로 교체될 것 — `# TODO(phase-4): replace with DeckPolicy::Scope` 마커 주석 남길 것.
- Browse 카드 데이터를 `data-browse-cards-value` JSON으로 전달 시 카드 `id`, `front`, `back` 필드만 포함 (hint, tags는 browse에서 불필요하면 제외 가능).
- `/study` 글로벌 큐는 덱별 큐와 동일한 LIMIT(10) + 정렬(`next_review_at ASC NULLS FIRST`) 사용.

</specifics>

<deferred>
## Deferred Ideas

- **Club deck in global study queue** — Phase 4 (DeckPolicy::Scope 교체 후).
- **Due-count badge on nav** — Phase 5 (Solid Cache TTL + invalidation).
- **Streak / mastery / today stats** — Phase 5.
- **Tournament event 학습 CTA** — Phase 5.
- **Per-day new card limit 설정 UI** — v1은 LIMIT 10 하드코딩.
- **키보드 단축키 힌트 UI** — 플래너 재량 (Phase 3 범위이나 구현 방식은 Claude 결정).

</deferred>

---

*Phase: 03-srs-learning-loop*
*Context gathered: 2026-05-30*
