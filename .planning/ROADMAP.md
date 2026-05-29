# Roadmap — 낱말카드 (Flashcards) v1

**Milestone:** M1 — 낱말카드 v1 (Flashcards SRS launch)
**Granularity:** standard (5 phases)
**Source of truth:** `.planning/PROJECT.md`
**Locked decisions:** `docs/adr/0001-flashcard-cardreview-shared-cards.md`
**Domain glossary:** `CONTEXT.md` (repo root)

## Core Value (recap)

학습 세션에서 카드를 평가하면 SM-2 알고리즘이 다음 복습 시각을 계산하고 Turbo Stream으로 즉시 다음 카드를 보여준다 — 이 사이클이 끊기면 모든 것이 무의미하다.

## Overview

Foundations first (schema, SM-2, factories, seed). Then a usable authoring UX for personal decks. Then the Core Value study loop. Then the full 3-tier authorization matrix with fork, club, and official integration. Finally, tournament linkage, hub statistics, and the due-count nav badge that brings users back.

Each phase ends in a green test suite and a feature a user can touch.

---

## Phases

- [x] **Phase 1: Foundations** — Schema, models, SM-2 service, factories, seed structure; data layer works in console *(완료: 2026-05-29)*
- [ ] **Phase 2: Deck + Card CRUD** — Authoring UX (single form + paste import + inline edit); nav entry; user can build a personal deck
- [ ] **Phase 3: SRS Learning Loop** — CardReview persistence, study controllers, Turbo Stream next-card swap, 4-button rating, flip browse
- [ ] **Phase 4: Permissions + Club/Official Integration** — Full Pundit coverage, 3-tier scopes, fork, club moderation/featured, official deck rendering, manager onboarding nudge
- [ ] **Phase 5: Tournament Linkage + Stats + Badge** — TournamentEventDeck join + UI, /decks hub stats (streak, today, mastery, 7-day forecast), nav due-count badge with Solid Cache

---

## Phase Details

### Phase 1: Foundations

**Goal**: 데이터 계층(모델·마이그레이션·시드·SM-2 서비스)이 콘솔에서 완전히 동작하고, 모든 후속 phase가 의존하는 정책 base와 팩토리가 자리잡는다.

**Depends on**: Nothing (first phase)

**Requirements** (from PROJECT.md Active list):
- Deck 모델 (3-tier) — schema only: `scope` enum (official/club/personal), polymorphic `owner`, `forked_from_deck_id`, `featured_at`
- Card 모델 — `front`, `back`, `hint`, `tags`, `card_type` enum (v1=basic), `position`; ActiveStorage `front_image`/`back_image` 모델·마이그레이션
- CardReview 모델 — `(user_id, card_id)` 유니크, `ease`, `interval_days`, `repetitions`, `next_review_at`, `last_reviewed_at`, `last_rating`
- 인덱스 `(user_id, next_review_at)` 필수
- TournamentEventDeck 조인 테이블 `(tournament_event_id, deck_id, position)` (스키마만 — UI는 Phase 5)
- SM-2 알고리즘 Ruby 서비스 (`Flashcards::Sm2Service`) — gem 없음, 4단계→0~5 quality 매핑, ease floor 1.3
- DeckPolicy / CardPolicy / CardReviewPolicy 파일 생성 + base 메서드 (default deny) — 디테일은 Phase 4에서 확정
- FactoryBot 팩토리: deck (3 scopes), card, card_review, tournament_event_deck
- 시드 구조 (`db/seeds/flashcards.yml` + 3 공식 덱 콘텐츠: "피클볼 기본 룰 30선", "영어 콜아웃 & 용어", "스코어링 시나리오 20")
- Fork 서비스 (`Flashcards::ForkDeckService`) — position 1..n 재정렬, CardReview 미복사

**Scope** (concrete deliverables):
- Migrations: `create_decks`, `create_cards`, `create_card_reviews`, `create_tournament_event_decks` (모두 reversible)
- Models with validations, associations (`has_many :cards`, `has_many :card_reviews`), `card_type` / `scope` enums
- `Card` cascade delete to `CardReview` (per ADR)
- `app/services/flashcards/sm2_service.rb` — pure Ruby, no AR; takes `(state, rating)`, returns `{ease:, interval_days:, repetitions:, next_review_at:}`
- `app/services/flashcards/fork_deck_service.rb`
- Seed loader (`db/seeds/flashcards.rb` or task) that reads `db/seeds/flashcards.yml` idempotently
- `app/policies/deck_policy.rb` / `card_policy.rb` / `card_review_policy.rb` — stubs returning false (Phase 4 wires real rules); `Scope` class shells in place

**Out of scope** (deferred):
- Pundit rule bodies for create/update/destroy/fork/featured/moderation → Phase 4
- `DeckPolicy::Scope` full 3-tier resolver → Phase 4
- Any controller, view, route → Phase 2+
- Image upload UI → permanently hidden in v1
- TournamentEventDeck controller/UI → Phase 5
- Streak / mastery / forecast queries → Phase 5
- Due-count cache → Phase 5

**Success criteria** (verifiable):
1. `bin/rails db:migrate` 그린, `bin/rails db:rollback STEP=4` 모두 가역
2. `bin/rails db:seed` 실행 후 콘솔에서 `Deck.official.count == 3`, 각 공식 덱 카드 수가 YAML 기대치와 일치
3. `bundle exec rspec spec/services/flashcards/sm2_service_spec.rb` 그린 — 4 ratings × {fresh, mature} = 8 case 모두 ease ∈ [1.3, ∞), interval ≥ 1
4. `Flashcards::ForkDeckService.call(source: official_deck, user: user)` 후 새 personal deck의 카드 position이 `1..n` contiguous이고 `CardReview` 0건
5. `bin/brakeman --no-pager` 신규 경고 0
6. `bundle exec rspec` 전체 그린 (Phase 1 spec만 추가, 기존 spec 무영향)

**Suggested test surface**:
- `spec/models/deck_spec.rb` — validations, enum, polymorphic owner, scopes (`.official`, `.club`, `.personal`)
- `spec/models/card_spec.rb` — validations, cascade delete to card_reviews, position default
- `spec/models/card_review_spec.rb` — uniqueness `(user_id, card_id)`, ease/interval defaults
- `spec/services/flashcards/sm2_service_spec.rb` — boundary table: 4 ratings × fresh/mature, ease floor enforcement, quality map verification
- `spec/services/flashcards/fork_deck_service_spec.rb` — position renormalization, CardReview not copied, `forked_from_deck_id` set
- FactoryBot lint — all factories build & save

**Plans**: TBD

---

### Phase 2: Deck + Card CRUD

**Goal**: 인증된 사용자가 브라우저에서 개인 덱을 만들고, 단일 폼 또는 paste import로 카드를 채우고, 인라인으로 편집할 수 있다.

**Depends on**: Phase 1

**Requirements** (from PROJECT.md Active list):
- `/decks` hub — 내 덱 목록 (3-tier 그룹). due/streak hero는 Phase 5에서 채움 (이 phase에서는 placeholder)
- 덱 CRUD: index, show, new, create, edit, update, destroy (personal scope 우선)
- 카드 CRUD: 단일 폼 ("저장하고 다음" 키보드 연속 입력)
- Paste import: textarea + 카드/면 구분자 선택 → 미리보기 → 일괄 저장
- 인라인 편집: 덱 상세 카드 표에서 Turbo Frame 단일 카드 편집
- 네비게이션: 유틸리티 dropdown에 "낱말카드" 추가 (포모도로 옆)
- 빈 상태 UX: `/decks` 0 덱 사용자에게 시드 덱 hero + "내 덱 만들기" + "붙여넣기 가져오기" CTA

**Scope** (concrete deliverables):
- Routes: `resources :decks` + `resources :cards` (shallow or nested); `post '/decks/:id/cards/import'`
- `DecksController` (index, show, new, create, edit, update, destroy) — personal scope fully functional; official/club read-only render allowed (full auth Phase 4)
- `CardsController` (new, create, edit, update, destroy) + `Cards::ImportsController` (new, preview, create)
- Stimulus controllers: `card_form_controller.js` (autofocus + save-and-next), `paste_import_controller.js` (separator preview, collision warning)
- ViewComponents or partials: `decks/_deck_card`, `cards/_form`, `cards/_row` (inline-edit Turbo Frame)
- `app/services/flashcards/paste_import_service.rb` — adversarial input safe (separator collision detection, empty line filter, whitespace strip)
- Tailwind layouts for `/decks`, `/decks/:id`, card forms; empty-state hero block
- Nav partial update: 유틸리티 dropdown 항목 추가 (badge는 Phase 5에서 자리만 잡음)

**Out of scope** (deferred):
- Full DeckPolicy 3-tier enforcement (this phase uses minimal `owner == current_user` check; cross-scope visibility hardening → Phase 4)
- Fork button UI → Phase 4
- Club deck creation UX (`scope: :club` from form) → Phase 4
- Official deck moderation UI → Phase 4
- Featured toggle → Phase 4
- Study button / SRS loop → Phase 3
- Image upload field (built but UI-hidden — confirm no form param leak)
- Stats / due badge / streak → Phase 5

**Success criteria** (verifiable):
1. 로그인 사용자가 `/decks/new` → 개인 덱 생성 → `/decks/:id` 진입 후 단일 폼으로 카드 5장 연속 추가 (Enter 키 워크플로우 동작)
2. Paste import: 탭 구분자로 10줄 붙여넣기 → 미리보기 → 일괄 저장 시 10 카드 생성; 면 내부에 탭 포함된 적대적 입력은 경고 표시 후 저장 차단
3. 덱 상세에서 카드 한 줄 인라인 편집 후 Turbo Frame swap (페이지 리로드 없음)
4. 비인증 접근 시 로그인 페이지로 리다이렉트, 본인이 아닌 personal 덱 접근 시 403/404
5. 유틸리티 dropdown에 "낱말카드" 메뉴 노출 → `/decks` 진입
6. 0 덱 사용자 `/decks` 진입 시 빈 상태 hero 렌더, 1개 이상 덱 보유 시 일반 목록 렌더
7. `bundle exec rspec` 그린, `bin/brakeman` 신규 경고 0
8. 이미지 첨부 필드가 form params(request spec)에 노출되지 않음

**Suggested test surface**:
- `spec/requests/decks_spec.rb` — CRUD happy path, unauthenticated redirect, foreign personal deck 403/404
- `spec/requests/cards_spec.rb` — create/update/destroy, inline edit Turbo Frame response
- `spec/requests/cards/imports_spec.rb` — preview, collision warning, bulk save
- `spec/services/flashcards/paste_import_service_spec.rb` — adversarial inputs (tab in content, empty lines, whitespace-only)
- `spec/system/deck_authoring_spec.rb` — Capybara: "저장하고 다음" Enter flow, paste import end-to-end, inline edit
- `spec/system/decks_navigation_spec.rb` — 유틸리티 메뉴 → /decks; 빈 상태 vs 일반 목록 분기
- `spec/requests/cards_spec.rb` 보안 케이스 — image attachment param이 거부되는지

**Plans**: TBD
**UI hint**: yes

---

### Phase 3: SRS Learning Loop

**Goal**: 사용자가 덱을 학습할 수 있고, 4단계 평가가 SM-2를 통해 다음 복습 시각을 계산하며, Turbo Stream으로 다음 카드가 즉시 swap된다. Core Value 실현.

**Depends on**: Phase 1 (SM-2 service, models), Phase 2 (덱·카드가 존재해야 학습 가능)

**Requirements** (from PROJECT.md Active list):
- SRS 학습 모드: due 카드 큐, 4단계 평가, Turbo Stream next-card swap
- Flip browse 모드 (빠른 훑어보기): 진도 미기록, 순서/셔플
- `/study` — 글로벌 큐 (모든 접근 가능 덱의 due 통합)
- `/decks/:id/study` — 덱별 학습
- `POST /card_reviews` → Turbo Stream 다음 카드 swap
- 4단계 평가 UI: 다시(1) / 어려움(2) / 보통(3) / 쉬움(4) + 키보드 단축키
- 세션 완료 화면

**Scope** (concrete deliverables):
- Routes: `get '/study'`, `get '/decks/:id/study'`, `resources :card_reviews, only: :create`, `get '/decks/:id/browse'`
- `StudyController` (global queue), `Decks::StudiesController` (per-deck), `Decks::BrowsesController` (flip browse)
- `CardReviewsController#create` — `respond_to format.turbo_stream`; uses `find_or_initialize_by(user_id:, card_id:)` + `update!` idempotency; rescues `ActiveRecord::RecordNotUnique`
- `app/services/flashcards/submit_review_service.rb` — orchestrates SM-2 call + CardReview upsert (cache bust hook stubbed for Phase 5)
- `app/queries/flashcards/study_queue_query.rb` — pulls due + new (limit), joins through deck, returns next card. **Phase 4** will swap raw access check for `DeckPolicy::Scope`. For now: own-personal + official decks only; club decks deferred to Phase 4.
- Stimulus `study_session_controller.js` — disable rating buttons on click (double-submit guard), keyboard shortcuts (1/2/3/4 keys), card flip animation
- Views: `study/show.html.erb` (card frame + rating buttons), `study/_card.html.erb` (turbo target), `study/_session_complete.html.erb`
- Browse view: flip-only, no rating buttons, clear "훑어보기 · 진도 미기록" 라벨
- Empty-deck guard: `study` 버튼 비활성화 + "카드를 먼저 추가하세요" 메시지

**Out of scope** (deferred):
- Club deck access in study queue → Phase 4 (queue currently honors personal + official only)
- Full `DeckPolicy::Scope` integration → Phase 4
- Streak / today's progress / mastery → Phase 5
- Due-count nav badge → Phase 5
- Tournament event "학습하기" CTA → Phase 5
- Per-day new card limit configuration UI (hardcode default 10 for v1)

**Success criteria** (verifiable):
1. 카드 5장 있는 개인 덱 → `/decks/:id/study` 진입 → 4단계 버튼 클릭 시 Turbo Stream으로 다음 카드 swap (full page reload 없음); 마지막 카드 후 "세션 완료" 화면 노출
2. `/study` 글로벌 큐에서 due 카드들이 순차 노출되며 평가 후 `CardReview` row 생성/업데이트 확인
3. 동일 카드 평가 버튼 더블클릭 시 단일 `CardReview` 만 생성/업데이트 (DB unique index + `find_or_initialize_by` 동작) — Capybara 슬로우 네트워크 system spec 그린
4. `/decks/:id/browse` 진입 시 평가 버튼 없음, 카드 flip만 가능, `CardReview` row 미생성
5. 빈 덱에서 "학습 시작" 버튼 비활성화 또는 안내 메시지 렌더
6. 평가별 SM-2 결과가 `Sm2Service` 출력과 일치 (request spec에서 DB 상태 검증)
7. `bundle exec rspec` 그린, `bin/brakeman` 신규 경고 0

**Suggested test surface**:
- `spec/requests/study_spec.rb` — 글로벌 큐 진입, 카드 노출 순서, 빈 큐 처리
- `spec/requests/decks/studies_spec.rb` — 덱별 학습 진입, 카드 없는 덱 가드
- `spec/requests/card_reviews_spec.rb` — POST Turbo Stream 응답, 더블 submit 멱등성, 평가별 SM-2 결과 DB 검증, out-of-range rating 거부 (`[1..4]`만 허용)
- `spec/services/flashcards/submit_review_service_spec.rb` — SM-2 호출 + upsert 시나리오
- `spec/queries/flashcards/study_queue_query_spec.rb` — due + new 한도, 정렬
- `spec/system/study_session_spec.rb` — Capybara: 5장 학습 → 세션 완료; 더블클릭 가드; 키보드 단축키 1/2/3/4
- `spec/system/browse_mode_spec.rb` — flip만 가능, 평가 버튼 부재

**Plans**: TBD
**UI hint**: yes

---

### Phase 4: Permissions + Club/Official Integration

**Goal**: 3-tier 덱 모델(official / club / personal)이 Pundit으로 완전히 통제되고, fork·club 작성·moderation·featured 토글·official 노출이 실제 사용자 그룹에 따라 정확히 동작한다.

**Depends on**: Phase 1 (policy 스텁, fork 서비스), Phase 2 (CRUD UI), Phase 3 (study queue 가드를 정식 Scope로 교체)

**Requirements** (from PROJECT.md Active list):
- Official 덱: site_admin (`role_admin?`) 작성, 전체 읽기/학습/fork 가능
- Club 덱: approved 멤버 작성, manager+owner+site_admin 모더레이션·featured 토글
- Personal 덱: 본인 전용, 비공개
- Fork: 공식/클럽 덱 → 개인 덱 복제 (UI 버튼 + 컨트롤러)
- `DeckPolicy` — scope별 접근·수정·삭제 규칙 (3-tier `Scope` 클래스)
- `CardPolicy` — `DeckPolicy`에 위임
- `CardReviewPolicy` — `record.user == current_user` + 해당 카드의 deck `show?` 검증 (Pitfall 8 방지)
- 클럽 manage 페이지 manager onboarding nudge (1회, dismiss 가능)

**Scope** (concrete deliverables):
- `DeckPolicy::Scope` 본문 완성 — official OR club(approved membership) OR personal(owner=current_user)
- `DeckPolicy#create?`, `update?`, `destroy?`, `fork?`, `feature?`, `moderate?` 규칙 — site_admin / club_owner / club_manager / approved_member / authenticated_user 매트릭스
- `CardPolicy` 전체 메서드를 `DeckPolicy`에 위임
- `CardReviewPolicy#create?` — user 일치 + `DeckPolicy.new(user, record.card.deck).show?` 이중 가드
- `ApplicationController` rescue `Pundit::NotAuthorizedError` (HTML + Turbo Stream 안전 응답 분기)
- `CardReviewsController` `before_action :authorize_card_deck` — 평가 직전 deck `show?` 재확인
- Fork UI: 공식/클럽 덱 show 페이지에 "내 덱으로 복제" 버튼 → `Decks::ForksController#create`
- 클럽 덱 작성 UX: `/decks/new?scope=club&club_id=N` (approved 멤버만), form에 `scope`/`owner` 마스 어사인먼트 차단 (컨트롤러에서 명시 설정)
- 클럽 덱 모더레이션: manager가 다른 멤버의 클럽 덱 수정/삭제 가능; `Decks::FeaturesController` (toggle `featured_at`)
- Official 덱 렌더링: 공식 덱 목록 hero/세션 (site_admin만 작성 진입점 노출)
- 클럽 manage 페이지 onboarding nudge 컴포넌트 — 클럽에 덱 0개 + 사용자가 manager일 때 1회 노출, `dismiss` 클릭 시 `User#dismissed_flashcard_nudge_at` 또는 cookie 저장
- Phase 3의 `study_queue_query`에서 raw 접근 체크를 `DeckPolicy::Scope`로 교체

**Out of scope** (deferred):
- TournamentEventDeck UI → Phase 5
- 통계 / 배지 → Phase 5
- 공개 UGC (personal 덱 공개) → v2

**Success criteria** (verifiable):
1. site_admin만 official 덱 생성 가능; approved 클럽 멤버만 해당 클럽 덱 생성 가능; 누구나 personal 덱 생성 가능
2. 클럽 manager는 자기 클럽 다른 멤버 덱 편집·삭제·featured 토글 가능; 일반 멤버는 본인 덱만 편집 가능
3. 인증 사용자가 공식 덱 fork 시 personal 덱 생성, position `1..n`, `CardReview` 0건, `forked_from_deck_id` 설정 — request spec
4. 클럽 멤버십 revoke 후 해당 사용자의 `/study` 글로벌 큐에서 그 클럽 덱 카드 사라짐 (request spec)
5. 클럽 멤버십 revoke 후 그 클럽 카드에 대한 `POST /card_reviews` 403 응답 (Pitfall 8)
6. 다른 클럽 덱을 form 조작으로 fork 시도 (`forked_from_deck_id` POST 변조) → 403
7. 클럽 manage 페이지에서 manager는 onboarding nudge 1회 노출, dismiss 후 재방문 시 미노출
8. `bundle exec rspec` 그린, `bin/brakeman` 신규 경고 0, Pundit 모든 컨트롤러 액션 `authorize` 호출 검증

**Suggested test surface**:
- `spec/policies/deck_policy_spec.rb` — 3-tier × 모든 행위자(site_admin / club_owner / club_manager / approved_member / non-member / authenticated_user) 매트릭스
- `spec/policies/card_policy_spec.rb` — 위임 정상 동작
- `spec/policies/card_review_policy_spec.rb` — user 일치 + deck show 이중 가드
- `spec/requests/decks_spec.rb` 추가 — scope=club 생성, scope=official 생성, moderation, featured toggle, 권한 거부 케이스
- `spec/requests/decks/forks_spec.rb` — happy path + `forked_from_deck_id` 변조 시도 403
- `spec/requests/study_spec.rb` 보강 — 클럽 멤버십 revoke 후 글로벌 큐 누수 없음
- `spec/requests/card_reviews_spec.rb` 보강 — 멤버십 revoke 후 평가 시도 403
- `spec/system/club_manage_nudge_spec.rb` — manager 노출, dismiss 영속화

**Plans**: TBD
**UI hint**: yes

---

### Phase 5: Tournament Linkage + Stats + Due-Count Badge

**Goal**: 토너먼트 종목에서 학습 덱으로 진입할 수 있고, `/decks` 허브가 살아있는 학습 진척도(streak, 오늘의 현황, 마스터리, 7일 예상)를 보여주며, 네비 due 카운트 배지가 사용자를 다시 끌어들인다.

**Depends on**: Phase 1 (TournamentEventDeck 스키마), Phase 2 (덱 hub UI), Phase 3 (CardReview 데이터 축적), Phase 4 (권한 매트릭스 — 토너먼트 매핑 권한 검증)

**Requirements** (from PROJECT.md Active list):
- `TournamentEventDeck` 매핑 권한: 해당 토너먼트의 club_manager + site_admin
- 후보 덱: 모든 공식 덱 + 매핑자 소속 클럽의 클럽 덱
- 설정 UI: `tournament_events/:id/edit`에 덱 매핑 멀티셀렉트 (position 정렬)
- 노출 UI: `tournament_events/:id` show 상단 "📚 이 종목 학습하기" 카드
- Streak (연속 학습 일수, KST 자정 기준)
- 오늘의 현황 (학습 완료 / due 카운트)
- 덱별 마스터리 % (`interval_days >= 21` 카드 비율)
- 7일 due 예상 (CSS 막대 차트, Tailwind utility만)
- 네비 "낱말카드" 라벨 옆 due 카운트 배지
- Solid Cache 1시간 TTL, 학습/카드 변경 시 invalidate

**Scope** (concrete deliverables):
- `TournamentEvents::DecksController` (edit/update) — 후보 덱 쿼리는 official ∪ (매핑자 소속 클럽 덱), position 재정렬 지원
- `tournament_events/_recommended_decks.html.erb` 파셜 → show 페이지 상단에 렌더 (덱 0개일 때 비노출)
- `app/queries/flashcards/streak_query.rb` — `Time.current.to_date` 기반, SQL group by KST date (timezone 변환), 연속 일수 계산
- `app/queries/flashcards/mastery_query.rb` — `cards.where('interval_days >= 21').count.to_f / cards.count`, division-by-zero 가드
- `app/queries/flashcards/due_forecast_query.rb` — `WHERE next_review_at BETWEEN today AND today+7`, `GROUP BY DATE(next_review_at)` 단일 쿼리
- `app/queries/flashcards/today_progress_query.rb` — 오늘 평가한 카드 수 vs 남은 due
- `/decks` hub 상단 hero 재구성: streak / 오늘 / 7일 예상 막대 차트 / 덱별 마스터리 % 표시
- `app/services/flashcards/due_count_cache.rb` — `Rails.cache.fetch("due_count/#{user.id}", expires_in: 1.hour)`; 명시적 invalidation 메서드
- Cache invalidation 훅: `CardReviewsController#create`, `CardsController#create/update/destroy`, `DecksController#destroy` (callback 아닌 controller에서 명시 호출)
- 네비 partial 업데이트: 라벨 옆 due 카운트 배지 (0이면 비표시)
- 세션 완료 화면(Phase 3에서 자리 잡힌)에 오늘의 진척 요약 표시
- 선택적 폴리시: 시드 콘텐츠 마지막 검수, 빈 상태 메시지 카피 다듬기

**Out of scope** (deferred):
- 이메일 / push / Telegram 알림 → v2
- 클럽 리더보드 / 뱃지 / 게임화 → v2
- 사용자별 타임존 설정 → KST 하드코딩 유지
- TournamentEventDeck → game_session 연결 → v2
- 차트 라이브러리 도입 → CSS 막대만 사용

**Success criteria** (verifiable):
1. Club manager가 자기 클럽이 주최한 토너먼트의 종목 edit 페이지에서 공식 덱 + 자기 클럽 덱을 매핑·재정렬 가능; 다른 클럽 덱은 후보에 미노출
2. 매핑된 종목 show 페이지 상단에 "📚 이 종목 학습하기" 카드 노출, 클릭 시 `/decks/:id/study` 진입
3. `/decks` hub에서 streak 숫자, 오늘 학습/남은 due, 덱별 마스터리 %, 7일 예상 막대 차트 모두 렌더
4. 23:58 KST에 카드 1장 평가 → 다음날 00:01 KST `streak` 1 유지(어제 카운트), 그날 추가 학습 시 streak +1 — `travel_to` model/query spec
5. 마스터리 % 계산이 빈 덱(0 카드)에서 0% 반환 (division-by-zero 가드)
6. 네비 due 카운트 배지가 캐시에서 즉시 노출, 카드 평가 후 즉시 갱신 (Solid Cache invalidate 검증)
7. 다른 클럽 manager가 본인 클럽 아닌 토너먼트 종목 매핑 시도 → 403
8. `bundle exec rspec` 그린, `bin/brakeman` 신규 경고 0
9. `EXPLAIN QUERY PLAN`으로 `card_reviews(user_id, next_review_at)` 인덱스 사용 확인

**Suggested test surface**:
- `spec/queries/flashcards/streak_query_spec.rb` — `travel_to` 23:58 KST, 자정 경계, 하루 거른 후 0 리셋
- `spec/queries/flashcards/mastery_query_spec.rb` — interval threshold, 빈 덱 0%, 부분 마스터리
- `spec/queries/flashcards/due_forecast_query_spec.rb` — 단일 쿼리(쿼리 카운트 검증), 7일 윈도우 경계, 접근 가능 덱만 집계
- `spec/queries/flashcards/today_progress_query_spec.rb`
- `spec/services/flashcards/due_count_cache_spec.rb` — fetch + invalidate, TTL
- `spec/requests/tournament_events/decks_spec.rb` — 매핑 권한 매트릭스, 후보 덱 필터, position 재정렬
- `spec/requests/tournament_events_spec.rb` 보강 — show 페이지 추천 덱 카드 렌더
- `spec/system/decks_hub_stats_spec.rb` — Capybara: streak/오늘/마스터리/7일 막대 차트 렌더
- `spec/system/due_count_badge_spec.rb` — 학습 후 배지 즉시 갱신
- 컨트롤러 레벨 정책 spec (TournamentEvent 매핑 권한)

**Plans**: TBD
**UI hint**: yes

---

## Coverage

| PROJECT.md Active 항목 | Phase |
|---|---|
| Deck 모델 schema (3-tier, polymorphic owner, forked_from, featured_at) | 1 |
| Official 덱 작성·읽기·학습·fork 규칙 | 1 (스키마) + 4 (Pundit) |
| Club 덱 작성·읽기·모더레이션·featured | 1 (스키마) + 4 (Pundit + UI) |
| Personal 덱 비공개 | 1 (스키마) + 4 (Pundit) |
| Fork (공식/클럽 → 개인) | 1 (서비스) + 4 (UI/권한) |
| Card 모델 + ActiveStorage 구조 | 1 |
| CardReview 모델 + 인덱스 | 1 |
| SM-2 Ruby 서비스 | 1 |
| 4단계 평가 UI | 3 |
| SRS 학습 모드 (Turbo Stream swap) | 3 |
| Flip browse 모드 | 3 |
| `/decks` hub | 2 (구조) + 5 (stats hero) |
| `/study` 글로벌 큐 | 3 (기본) + 4 (정식 Scope 교체) |
| `/decks/:id/study` | 3 |
| `POST /card_reviews` | 3 |
| 단일 카드 폼 "저장하고 다음" | 2 |
| Paste import | 2 |
| 인라인 편집 | 2 |
| DeckPolicy / CardPolicy / CardReviewPolicy | 1 (스텁) + 4 (본문) |
| TournamentEventDeck 조인 테이블 | 1 (스키마) + 5 (UI/권한) |
| 토너먼트 매핑 권한 + 후보 덱 | 5 |
| `tournament_events/:id/edit` 매핑 UI | 5 |
| `tournament_events/:id` 추천 덱 카드 | 5 |
| Streak | 5 |
| 오늘의 현황 | 5 |
| 덱별 마스터리 % | 5 |
| 7일 due 예상 | 5 |
| 네비 due 카운트 배지 | 5 |
| Solid Cache + invalidation | 5 |
| 시드 콘텐츠 (공식 덱 3종 + YAML) | 1 |
| `/decks` 빈 상태 UX | 2 |
| 클럽 manage onboarding nudge | 4 |
| 유틸리티 dropdown "낱말카드" | 2 |

**Coverage: 100%** — 모든 Active 요구사항이 정확히 하나 이상의 phase에 매핑됨. 일부 항목은 스키마(Phase 1) → UI/권한(후속 Phase) 자연 분할.

---

## Progress

**Execution Order:** Phases execute in numeric order: 1 → 2 → 3 → 4 → 5. Phase 5는 Phase 4의 권한 베이스에 의존하므로 직렬 실행 권장.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundations | 1/1 | Complete | 2026-05-29 |
| 2. Deck + Card CRUD | 0/TBD | Not started | - |
| 3. SRS Learning Loop | 0/TBD | Not started | - |
| 4. Permissions + Club/Official | 0/TBD | Not started | - |
| 5. Tournament + Stats + Badge | 0/TBD | Not started | - |

---

## Cross-Phase Risk Register (from PITFALLS.md)

| Pitfall | Prevention Phase | Verification Gate |
|---|---|---|
| SM-2 rating scale mismatch | 1 | Sm2Service spec: 4 ratings × fresh/mature |
| Fork position chaos | 1 | ForkDeckService spec: contiguous 1..n, CardReview 0 |
| Polymorphic owner N+1 | 2 | `/decks` request spec with 10+ decks, optionally Bullet in dev |
| Paste import separator collision | 2 | PasteImportService spec: adversarial inputs |
| XSS in card preview | 2 | system spec: `<script>` in front 필드 자동 escape |
| Image attachment param leak | 2 | request spec: image params 거부 |
| Turbo Stream double-submission | 3 | system spec: slow-network 이중 클릭 |
| Out-of-range rating | 3 | request spec: rating ∉ [1..4] → BadRequest |
| Global queue access leak (membership revoked) | 4 | request spec: revoke → `/study` no club cards |
| CardReviewPolicy bypass | 4 | request spec: revoke → POST /card_reviews 403 |
| Fork param 변조 | 4 | request spec: `forked_from_deck_id` 변조 → 403 |
| Streak KST off-by-one | 5 | query spec: `travel_to` 23:58 KST |
| Mastery division-by-zero | 5 | query spec: 빈 덱 |
| 7-day forecast unbounded | 5 | query spec: 단일 쿼리 카운트 |
| Cache stale due badge | 5 | system spec: 평가 후 즉시 갱신 |
| TournamentEventDeck cross-club | 5 | request spec: 다른 클럽 덱 매핑 시도 403 |

---

## Locked Decisions (do not revisit during planning)

- **Card는 덱당 단일본**, 사용자별 SRS 상태는 `CardReview(user_id, card_id)`에 분리 — ADR 0001
- **Fork는 학습 전제 조건이 아님** — 접근 가능한 덱은 원본 그대로 학습
- SM-2 Ruby 자작, gem 없음 — 4단계 평가, ease floor 1.3
- 4단계 평가: 다시(1) / 어려움(2) / 보통(3) / 쉬움(4)
- `Deck.scope` enum + 폴리모픽 `owner` (official=nil owner)
- Hard delete cascade (Card → CardReview)
- 인앱 배지만 (이메일/push 없음 v1)
- KST 하드코딩 (`config.time_zone = "Seoul"`)
- 한국어 하드코딩 UI (i18n yml 없음)
- TournamentEvent 단위 덱 매핑 (game_session 연결 v2)
- 이미지 첨부는 코드만 빌드, UI 숨김 (S3 미설정)

---

*Created: 2026-05-29 — derived from PROJECT.md v1 + research/SUMMARY.md + ADR 0001*
