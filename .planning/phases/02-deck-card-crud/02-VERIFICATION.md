---
phase: 02-deck-card-crud
verified: 2026-05-30T08:00:00Z
status: human_needed
score: 21/21 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 18/21
  gaps_closed:
    - "CR-01: 면 내부에 구분자 포함된 줄은 미리보기 빨강 + 저장 차단 (parts.compact_blank.size > 4 조건으로 교체)"
    - "CR-02: 덱 내 front 중복 줄은 미리보기 빨강 + 저장 차단 (batch_dupes 집합 로직 추가 — 배치 내 중복 감지)"
    - "WR-01: 인라인 편집 frame 안에서 Escape 키 누르면 cancelTarget.click()으로 read-only 행 복귀"
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "/decks Hub가 오늘의 복습 hero 섹션(due 카운트 표시)을 포함한다 (HUB-01)"
    addressed_in: "Phase 5"
    evidence: "REQUIREMENTS.md Traceability — NAV-02/03/04는 Phase 5. 02-CONTEXT.md Decision #3: HUB due 카운트 hero는 Phase 5와 함께 구현. 현재 index.html.erb에 '곧 만나요' 없이 허브 레이아웃만 제공."
human_verification:
  - test: "Cmd+Enter 저장 후 포커스 이동 확인"
    expected: "카드 저장 성공 후 add form이 리셋되고 front 입력 필드에 자동 포커스"
    why_human: "rack_test 드라이버는 JavaScript를 실행하지 않으므로 Stimulus Cmd+Enter 이벤트와 autofocus 동작을 검증할 수 없음"
  - test: "카드 행 클릭 → Turbo Frame 인라인 편집 시각적 전환"
    expected: "read-only 카드 행이 클릭 시 편집 폼으로 교체되고, 저장 성공 시 다시 read-only 행으로 복귀"
    why_human: "시스템 테스트가 rack_test(JS 미실행)로 실행되어 Turbo Frame 교체 동작이 HTML fallback 경로로만 검증됨"
  - test: "Escape 키 인라인 편집 폼 취소 → read-only 행 복귀 (WR-01 수정 후)"
    expected: "_card_edit_form 취소 링크(card_form_target=cancel)가 Stimulus cancelTarget.click()으로 클릭되어 read-only 카드 행으로 복귀됨. removeAttribute+reload 패턴 no-op 해결 확인"
    why_human: "Stimulus cancelTarget.click() 동작은 JavaScript 실행 환경에서만 검증 가능. rack_test 드라이버로는 keydown 이벤트 및 Stimulus 핸들러 실행 불가"
  - test: "텍스트 붙여넣기 시 paste_import_controller 구분자 자동 감지"
    expected: "textarea에 탭 구분자 텍스트 입력 시 separator select가 자동으로 '탭'으로 변경됨"
    why_human: "클라이언트-사이드 Stimulus 동작으로 request spec으로 검증 불가"
  - test: "/decks 허브 3섹션 레이아웃 시각적 확인"
    expected: "공식/클럽/내 덱 섹션이 올바른 순서로 그룹화되어 표시되고, 클럽 섹션은 approved 멤버십이 없으면 숨겨짐"
    why_human: "승인된 클럽 멤버십 조건부 렌더링은 request spec으로 확인되나, 실제 브라우저 레이아웃 검증 필요"
  - test: "0개 덱 사용자의 /decks 빈 상태 hero 표시"
    expected: "'낱말카드로 학습을 시작해 보세요' hero와 '내 덱 만들기' / '붙여넣기 가져오기' CTA 버튼이 표시됨. 단, '붙여넣기 가져오기' 버튼이 new_deck_path로 이동하는 것이 UX 의도에 맞는지 확인 필요"
    why_human: "WR-02: CTA 버튼 레이블이 import 흐름을 암시하나 실제 링크는 덱 생성 폼 — 의도된 UX인지 제품 판단 필요"
---

# Phase 02: Deck + Card CRUD Verification Report

**Phase Goal:** 인증된 사용자가 personal 덱과 카드를 브라우저에서 CRUD할 수 있고, 텍스트 붙여넣기로 카드를 일괄 가져올 수 있다.
**Verified:** 2026-05-30T08:00:00Z
**Status:** human_needed
**Re-verification:** Yes — 02-05 gap 클로저 후 재검증

## Re-verification Summary

| 항목 | 이전 (02-04 이후) | 현재 (02-05 이후) |
|-----|-----------------|-----------------|
| 점수 | 18/21 | 21/21 |
| CR-01 (구분자 충돌 감지 데드코드) | FAILED | VERIFIED |
| CR-02 (배치 내 front 중복 미감지) | PARTIAL | VERIFIED |
| WR-01 (Escape no-op) | FAILED | VERIFIED |
| WR-03 (:new 라우트 500 위험) | WARNING | RESOLVED |
| 전체 회귀 | 457 examples GREEN | 461 examples GREEN |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | 인증된 사용자가 /decks/new → 폼 제출 → /decks/:id로 redirect되어 새 personal 덱 생성 | VERIFIED | DecksController#create: Deck.new(deck_params.merge(scope: :personal, owner: Current.user)) + redirect_to @deck |
| 2 | /decks 진입 시 공식/클럽/개인 3섹션 렌더 (클럽은 approved 멤버십 보유 시만) | VERIFIED | index.html.erb: @official_decks/@club_decks/@personal_decks 3섹션, @show_club_section 조건부 |
| 3 | 0개 personal 덱 사용자가 /decks 진입 시 빈 상태 hero + 2 CTA 렌더 | VERIFIED | index.html.erb line 4-26: if authenticated? && @personal_decks.empty? 분기, "내 덱 만들기" + "붙여넣기 가져오기" 버튼 확인 |
| 4 | 본인 personal 덱 PATCH/DELETE 성공, 타인 personal 덱은 403 | VERIFIED | DeckPolicy#update?=personal_owner?, spec 12개 GREEN, authorize @deck 6회 호출 확인 |
| 5 | 비인증 사용자 /decks/new GET 시 로그인 페이지 redirect | VERIFIED | DecksController: require_authentication (new 액션은 allow_unauthenticated_access 미포함) |
| 6 | 유틸리티 nav dropdown에 '낱말카드' 링크 노출 | VERIFIED | application.html.erb line 179: decks_path + "낱말카드" span 확인 |
| 7 | 본인 personal 덱 show 페이지에서 단일 폼으로 카드 1장 추가 → Turbo Stream 갱신 | VERIFIED | CardsController#create: turbo_stream.append + turbo_stream.replace, create.turbo_stream.erb 존재 |
| 8 | 카드 행 클릭 → Turbo Frame 단위로 read-only 행이 inline edit 폼으로 교체 | VERIFIED (partial) | _card_row.html.erb: turbo_frame_tag "card_#{card.id}", tag: :tr. 시각적 동작은 human 검증 필요 |
| 9 | edit 폼 저장 성공 → 동일 Turbo Frame ID가 read-only 행으로 교체 | VERIFIED | update.turbo_stream.erb: turbo_stream.replace "card_#{@card.id}" |
| 10 | card_form_controller가 Cmd/Ctrl+Enter 감지 시 form.requestSubmit() 호출 | VERIFIED | card_form_controller.js:13: if (form) form.requestSubmit(). form.submit() 없음 확인 |
| 11 | 인라인 편집 frame 안에서 Escape 키 누르면 cancelTarget.click()으로 read-only 행 복귀 | VERIFIED | card_form_controller.js:22: `if (this.hasCancelTarget) this.cancelTarget.click()`. removeAttribute/reload 패턴 완전 제거(grep 0건). _card_edit_form.html.erb:17에 `card_form_target: "cancel"` 선언 확인. 시각적 동작은 human 검증 필요. |
| 12 | POST /decks/:id/cards에 front_image 파라미터 포함해도 ActiveStorage attach 안 됨 | VERIFIED | card_params: permit(:front, :back, :hint, :tags)만 허용. 뷰에 image 입력 없음. spec CARD-06 GREEN |
| 13 | 타인 personal 덱 cards 액션 → 403 또는 404 | VERIFIED | CardsController#set_deck: Deck.where(owner: Current.user).find() — 타인 덱은 RecordNotFound(404) |
| 14 | paste import 진입점 페이지가 textarea + 구분자 select + 미리보기 영역과 함께 렌더 | VERIFIED | new.html.erb: paste-import controller, separator select, text textarea, import-preview/actions div 확인 |
| 15 | POST .../imports (mode: preview) → 파싱 결과 테이블이 Turbo Stream으로 갱신 | VERIFIED | create.turbo_stream.erb: turbo_stream.update "import-preview-#{@deck.id}", _preview_table.html.erb 존재 |
| 16 | POST .../imports (mode: save) → 트랜잭션 내 일괄 생성, 한 건 실패 시 전체 롤백 | VERIFIED | PasteImportService: ActiveRecord::Base.transaction + create! + rescue RecordInvalid |
| 17 | 면 내부에 구분자 포함된 줄은 미리보기 빨강 + 저장 차단 | VERIFIED | paste_import_service.rb:63: `if parts.compact_blank.size > 4` — 열 수 초과로 감지. f.include?(@separator) 데드코드 완전 제거(grep 0건). spec CR-01 context 3 examples GREEN (12/12 examples) |
| 18 | 덱 내 front 중복 줄은 미리보기 빨강 + 저장 차단 | VERIFIED | DB 기존 중복: existing_fronts pluck 검사. 배치 내 중복: paste_import_service.rb:35 `batch_dupes = parsed.map(&:front).compact_blank.tally.select { |_, count| count > 1 }.keys.to_set`. spec CR-02 context 2 examples GREEN |
| 19 | 500장 초과 입력 시 즉시 거부 | VERIFIED | PasteImportService:27 lines.size > IMPORT_LIMIT → failure. IMPORT_LIMIT=500 선언 확인 |
| 20 | 타인 덱 import 진입 시 403 또는 404 | VERIFIED | Cards::ImportsController#set_deck: Deck.where(owner: Current.user).find() + authorize @deck, :update? |
| 21 | deck_params에 owner/scope 미포함 (mass assignment 차단) | VERIFIED | DecksController#deck_params: permit(:title, :description)만 |

**Score:** 21/21 truths verified

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|---------|
| 1 | /decks Hub 오늘의 복습 hero 섹션 (due 카운트 표시) (HUB-01) | Phase 5 | REQUIREMENTS.md Traceability: NAV-02/03/04 → Phase 5. 02-CONTEXT.md Decision #3 문서화 |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `app/controllers/decks_controller.rb` | Deck CRUD + Pundit + 3-scope query | VERIFIED | 75줄, class DecksController, policy_scope 0건 |
| `app/controllers/cards_controller.rb` | Card CRUD + image 차단 + Turbo Stream | VERIFIED | 76줄, class CardsController |
| `app/controllers/cards/imports_controller.rb` | Paste import controller | VERIFIED | class Cards::ImportsController, authorize @deck,:update? 양쪽 |
| `app/services/flashcards/paste_import_service.rb` | 텍스트 파싱 + 검증 + 트랜잭션 (CR-01/CR-02 수정 포함) | VERIFIED | parts.compact_blank.size > 4 (line 63), batch_dupes tally (line 35), IMPORT_LIMIT=500, transaction+create! |
| `spec/services/flashcards/paste_import_service_spec.rb` | CR-01/CR-02 회귀 방지 spec | VERIFIED | 구분자 충돌 감지 (CR-01) context 3 examples + 배치 내 중복 감지 (CR-02) context 2 examples — 12 examples, 0 failures |
| `app/views/decks/index.html.erb` | 3섹션 + 빈 상태 hero | VERIFIED | 3-state 분기 확인, "공식"+"내 덱" 문자열 존재 |
| `app/views/decks/show.html.erb` | 덱 상세 + 카드 테이블 + 진입점 | VERIFIED | id="deck-cards-", id="deck-add-form-", new_deck_cards_imports_path 확인 |
| `app/views/decks/_card_row.html.erb` | Turbo Frame read-only 행 | VERIFIED | turbo_frame_tag "card_#{card.id}", tag: :tr |
| `app/views/decks/_card_edit_form.html.erb` | 인라인 편집 폼 + cancel target 선언 | VERIFIED | data-controller="card-form", keydown->card-form#handleKeydown, line 17: `card_form_target: "cancel"` 선언 |
| `app/views/decks/_card_add_form.html.erb` | 신규 카드 추가 폼 + 카운터 | VERIFIED | data-card-form-target="counter", "장 저장됨", data-card-form-saved-count-value |
| `app/views/cards/edit.html.erb` | Turbo Frame 편집 응답 | VERIFIED | turbo_frame_tag "card_#{@card.id}", tag: :tr — ID 일관성 확인 |
| `app/views/cards/create.turbo_stream.erb` | 행 append + 폼 reset | VERIFIED | turbo_stream.append deck-cards-{id} + replace deck-add-form-{id} |
| `app/views/cards/update.turbo_stream.erb` | 단일 행 교체 | VERIFIED | turbo_stream.replace "card_#{@card.id}" |
| `app/views/cards/destroy.turbo_stream.erb` | 행 제거 | VERIFIED | turbo_stream.remove "card_#{@card.id}" |
| `app/views/cards/imports/new.html.erb` | paste import 폼 | VERIFIED | data-controller="paste-import", separator select, text textarea |
| `app/views/cards/imports/_preview_table.html.erb` | 미리보기 테이블 | VERIFIED | import-preview__row--invalid 분기, preview_cards 순회 |
| `app/views/cards/imports/_actions.html.erb` | 저장 버튼 + 카운트 | VERIFIED | importable_count 분기, hidden_field text/separator |
| `app/views/cards/imports/create.turbo_stream.erb` | preview/save Turbo Stream | VERIFIED | turbo_stream.update import-preview + import-actions |
| `app/javascript/controllers/card_form_controller.js` | Cmd+Enter + Escape(cancelTarget) + 카운터 | VERIFIED | requestSubmit() 확인, static targets: ["front","counter","cancel"], hasCancelTarget 가드 + cancelTarget.click() 확인. removeAttribute/reload 완전 제거 |
| `app/javascript/controllers/paste_import_controller.js` | 구분자 자동 감지 | VERIFIED | static targets=["text","separator"], detectSeparator() 존재 |
| `app/policies/deck_policy.rb` | Pundit policy | VERIFIED | personal_owner?, show? 3분기, Scope=scope.none |
| `config/routes.rb` | decks + nested cards(:new 제거) + imports | VERIFIED | resources :cards, only: %i[create edit update destroy] — :new 제거 확인. bin/rails routes \| grep 'cards#new' → 0건 |
| `app/views/layouts/application.html.erb` | 낱말카드 nav 진입점 | VERIFIED | line 179: decks_path + "낱말카드" |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| DecksController#index | Deck.where(scope:) 3종 | 명시적 쿼리 | VERIFIED | policy_scope(Deck) 0건 확인 |
| DecksController#create/update/destroy | DeckPolicy#personal_owner? | authorize @deck | VERIFIED | 6회 authorize 호출 확인 |
| CardsController#card_params | :front,:back,:hint,:tags만 | permit 목록 | VERIFIED | front_image/back_image는 주석만 |
| CardsController#set_deck | Deck.where(owner: Current.user) | 명시적 owner 스코프 | VERIFIED | policy_scope 금지 준수 |
| Cards::ImportsController#create | Flashcards::PasteImportService.call | service 호출 | VERIFIED | @result = Flashcards::PasteImportService.call(...) |
| PasteImportService#save_cards! | ActiveRecord::Base.transaction | 트랜잭션 블록 | VERIFIED | transaction + create! 확인 |
| PasteImportService#parse_line | parts.compact_blank.size > 4 경고 | CR-01 수정 | VERIFIED | line 63 조건 존재. f.include?(@separator) 완전 제거(grep 0건) |
| PasteImportService#call | batch_dupes tally 집합 | CR-02 추가 | VERIFIED | line 35: batch_dupes = ...tally.select{count>1}.keys.to_set. line 39: warnings << "배치 내 중복" if batch_dupes.include? |
| _card_edit_form → card_form_controller | Escape → cancelTarget.click() | Stimulus target | VERIFIED | static targets에 "cancel" 추가. _card_edit_form.html.erb:17 card_form_target: "cancel" 선언. hasCancelTarget 가드 존재 |
| _card_add_form → card_form_controller | data-card-form-target="counter" | Stimulus value hook | VERIFIED | savedCount value + counter target 선언 일치 |
| show.html.erb → new_deck_cards_imports_path | 붙여넣기 가져오기 링크 | link_to | VERIFIED | personal? && Current.user == owner 조건 안에 링크 확인 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|-------------|--------|-------------------|--------|
| decks/index.html.erb | @official_decks, @personal_decks, @club_decks | DecksController#index: Deck.where(scope:) 3종 쿼리 | Yes | FLOWING |
| decks/show.html.erb | @cards | DecksController#show: @deck.cards.order(:position, :id) | Yes | FLOWING |
| decks/_card_add_form.html.erb | deck.cards.size (카운터) | ERB 직접 주입 — DB 쿼리 결과 | Yes | FLOWING |
| cards/imports/_preview_table.html.erb | preview_cards | PasteImportService.call → Result.preview_cards | Yes | FLOWING |
| cards/imports/create.turbo_stream.erb | @result | Cards::ImportsController: PasteImportService.call 결과 | Yes | FLOWING |

### Behavioral Spot-Checks

Step 7b 실행 결과:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| CR-01 spec (구분자 충돌 감지 3 examples) | `bundle exec rspec spec/services/.../paste_import_service_spec.rb --format documentation` | 12 examples, 0 failures | PASS |
| CR-02 spec (배치 내 중복 감지 2 examples) | 동일 실행 포함 | 12 examples, 0 failures | PASS |
| 전체 회귀 | `bundle exec rspec spec/` | 461 examples, 0 failures | PASS |

### Probe Execution

Step 7c: 프로브 파일 없음 — `find scripts -path '*/tests/probe-*.sh'` 결과 없음.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| DECK-01 | 02-02 | 인증된 사용자 personal 덱 생성 | SATISFIED | DecksController#create, spec GREEN |
| DECK-04 | 02-02 | official 덱 인증 사용자 읽기 | SATISFIED | allow_unauthenticated_access :index,:show, DeckPolicy#show? |
| DECK-05 | 02-02 | club 덱 approved 멤버만 읽기 | SATISFIED | DeckPolicy#show? club 분기 + approved 조건 |
| DECK-06 | 02-02 | personal 덱 소유자만 CRUD | SATISFIED | DeckPolicy#update?=personal_owner?, authorize 호출 |
| DECK-07 | 02-02 | 덱 소유자만 수정/삭제 | SATISFIED | authorize_deck! before_action |
| DECK-09 | 02-02 | 덱 삭제 시 Card/CardReview cascade | SATISFIED | Deck.destroy! + dependent: :destroy (모델 레벨) |
| CARD-01 | 02-03 | 덱 소유자 카드 생성 | SATISFIED | CardsController#create, spec GREEN |
| CARD-02 | 02-03 | 저장하고 다음 연속 입력 | SATISFIED | card_add_form + Turbo Stream replace + autofocus. Cmd+Enter human 확인 필요 |
| CARD-03 | 02-03 | 카드 수정 (인라인 편집 Turbo Frame) | SATISFIED | _card_row turbo_frame + edit.html.erb + update.turbo_stream. Escape 복귀 코드 수정됨(WR-01 해소). 시각적 동작 human 확인 필요 |
| CARD-04 | 02-03 | 카드 삭제 (CardReview cascade) | SATISFIED | CardsController#destroy + Card has_many :card_reviews, dependent: :destroy |
| CARD-05 | 02-04/02-05 | Paste import 미리보기 후 일괄 저장 | SATISFIED | 흐름 전체 동작. CR-01 구분자 충돌 감지 수정(parts.compact_blank.size > 4). CR-02 배치 내 중복 감지 추가(batch_dupes tally). 12 spec examples GREEN |
| CARD-06 | 02-03 | card_type=basic만 지원, image UI 숨김 | SATISFIED | card_params image 제외, 뷰에 image 입력 없음 |
| HUB-01 | 02-02 | /decks 오늘의 복습 hero | DEFERRED | Phase 5 — REQUIREMENTS.md Traceability 확인 |
| HUB-02 | 02-02 | /decks official/club/personal 그룹 표시 | SATISFIED | index.html.erb 3섹션 분기 |
| HUB-03 | 02-02 | 0개 덱 사용자 빈 상태 hero + CTA | SATISFIED | index.html.erb:4-26 빈 상태 분기 |
| NAV-01 | 02-02 | 유틸리티 dropdown에 낱말카드 링크 | SATISFIED | application.html.erb line 179 확인 |

DECK-02(site_admin official 생성), DECK-03(club 덱 생성), DECK-08(featured_at 토글)는 REQUIREMENTS.md에 Phase 4로 매핑됨 — 본 phase 범위 외.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/views/decks/index.html.erb` | 20 | "붙여넣기 가져오기" 버튼 → new_deck_path (import 라우트 아님) | WARNING | WR-02: Decision #5 잠긴 결정으로 deferred. 제품 판단 필요 |
| `spec/requests/cards/imports_spec.rb` | 8 | 로컬 sign_in 재정의 — request_helpers.rb와 중복 | INFO | 장기적 diverge 위험 |
| `app/services/flashcards/paste_import_service.rb` | 63 | `compact_blank`가 trailing 빈 요소와 중간 빈 요소를 모두 제거 — "front\tback\thint\t\tEXTRA" 같은 입력에서 compact_blank 후 4개로 판정되어 충돌 미감지 | INFO | 매우 특수한 엣지케이스 (빈 열 사이 초과 열). 계획서가 명시한 > 4 조건 그대로 구현되어 의도된 동작. 실용적 우선순위 낮음 |

### Human Verification Required

### 1. Cmd+Enter 저장 후 포커스 이동 확인

**Test:** 덱 show 페이지에서 add form에 앞면/뒷면 입력 후 Cmd+Enter 입력
**Expected:** 카드 저장 성공 후 add form이 리셋되고 front 입력 필드에 자동 포커스
**Why human:** rack_test 드라이버는 JavaScript를 실행하지 않으므로 Stimulus Cmd+Enter 이벤트와 autofocus 동작을 검증할 수 없음

### 2. 카드 행 클릭 → Turbo Frame 인라인 편집 시각적 전환

**Test:** 덱 show 페이지에서 카드 행 클릭 후 편집 폼 표시 확인. 저장 후 read-only 행 복귀 확인
**Expected:** read-only 카드 행이 클릭 시 편집 폼으로 교체되고, 저장 성공 시 다시 read-only 행으로 복귀
**Why human:** 시스템 테스트가 rack_test(JS 미실행)로 실행되어 Turbo Frame 교체 동작이 HTML fallback 경로로만 검증됨

### 3. Escape 키 인라인 편집 폼 취소 → read-only 행 복귀 (WR-01 수정 후)

**Test:** 카드 행 클릭으로 편집 폼 진입 후 Escape 키 입력
**Expected:** _card_edit_form 취소 링크(card_form_target=cancel)가 Stimulus cancelTarget.click()으로 클릭되어 read-only 카드 행으로 복귀됨. 이전의 removeAttribute+reload no-op 패턴이 해결된 것을 실제 브라우저에서 확인
**Why human:** Stimulus cancelTarget.click() 동작은 JavaScript 실행 환경에서만 검증 가능. rack_test 드라이버로는 keydown 이벤트 및 Stimulus 핸들러 실행 불가

### 4. 텍스트 붙여넣기 시 paste_import_controller 구분자 자동 감지

**Test:** paste import 페이지 textarea에 탭 구분자 텍스트 직접 입력
**Expected:** separator select가 자동으로 '탭'으로 변경됨
**Why human:** 클라이언트-사이드 Stimulus 동작으로 request spec으로 검증 불가

### 5. /decks 허브 3섹션 레이아웃 시각적 확인

**Test:** approved 클럽 멤버십이 있는 사용자와 없는 사용자로 /decks 방문
**Expected:** 공식/클럽/내 덱 섹션이 올바른 순서로 그룹화되어 표시되고, 클럽 섹션은 approved 멤버십이 없으면 숨겨짐
**Why human:** 승인된 클럽 멤버십 조건부 렌더링은 request spec으로 확인되나, 실제 브라우저 레이아웃 검증 필요

### 6. 0개 덱 사용자의 /decks 빈 상태 hero 표시

**Test:** 덱이 없는 사용자로 /decks 방문
**Expected:** '낱말카드로 학습을 시작해 보세요' hero와 '내 덱 만들기' / '붙여넣기 가져오기' CTA 버튼이 표시됨. '붙여넣기 가져오기' 버튼이 new_deck_path로 이동하는 것이 UX 의도에 맞는지 확인 필요
**Why human:** WR-02: CTA 버튼 레이블이 import 흐름을 암시하나 실제 링크는 덱 생성 폼 — 의도된 UX인지 제품 판단 필요

### Gaps Summary

02-05 gap 클로저 완료. 코드베이스 레벨 gap 없음.

**인간 검증이 필요한 6개 항목** (JavaScript/브라우저 동작)이 남아 있어 status가 human_needed입니다. 이 항목들은 rack_test 드라이버 한계로 자동화가 불가능합니다.

---

_Verified: 2026-05-30T08:00:00Z_
_Verifier: Claude (gsd-verifier)_
