---
phase: 02-deck-card-crud
verified: 2026-05-30T05:00:00Z
status: gaps_found
score: 18/21 must-haves verified
overrides_applied: 0
gaps:
  - truth: "면 내부에 구분자 포함된 줄은 미리보기 빨강 + 저장 차단"
    status: failed
    reason: |
      paste_import_service.rb:60의 구분자 충돌 감지 코드가 데드코드다.
      split(@separator, -1) 호출이 구분자를 모든 위치에서 분리하므로,
      결과 배열의 어떤 요소도 구분자를 포함할 수 없다.
      f.include?(@separator)는 항상 false를 반환한다.
      02-04-SUMMARY의 "Deferred Issues" 섹션이 이를 팀 스스로 인정했으나 그대로 출시.
      spec은 result.success?만 검사하여 그린 테스트가 동작을 보증하지 않는다.
    artifacts:
      - path: "app/services/flashcards/paste_import_service.rb"
        issue: "line 56: split(@separator, -1) 이후 line 60: f.include?(@separator)는 논리적으로 항상 false — 데드코드"
      - path: "spec/services/flashcards/paste_import_service_spec.rb"
        issue: "line 35 테스트가 result.success?만 검증, warnings 배열을 검증하지 않아 데드코드를 포착하지 못함"
    missing:
      - "parse_line 내부의 구분자 충돌 감지를 parts.size > 4 조건으로 교체"
      - "spec에 result.preview_cards.first.warnings.any?와 importable? == false 검증 추가"

  - truth: "덱 내 front 중복 줄은 미리보기 빨강 + 저장 차단"
    status: partial
    reason: |
      DB에 이미 존재하는 front와의 중복은 차단된다(pluck 쿼리).
      그러나 같은 배치 안에서 동일한 front 값이 두 번 등장하면 둘 다 통과하여 저장된다.
      batch_dupes/batch_fronts/group_by 패턴이 서비스 코드에 없음(grep 결과 0건 확인).
      DB에 (deck_id, front) 유니크 인덱스도 없어 최후 방어선도 없다.
      SUMMARY가 "덱 내 front 중복 검출 시 저장 차단" PASSED라고 주장하지만,
      이는 DB중복 시나리오만 테스트했고 배치-내부 중복은 커버하지 않는다.
    artifacts:
      - path: "app/services/flashcards/paste_import_service.rb"
        issue: "call 메서드에 배치-내부 중복 감지 로직(batch_dupes 집합 검사) 없음"
    missing:
      - "call 메서드에 배치-내부 중복 front 감지: batch_fronts.group_by(&:itself).select{|_,v|v.size>1}.keys.to_set 패턴 추가"
      - "spec에 동일 배치 내 중복 front 시나리오 추가"

  - truth: "인라인 편집 frame 안에서 Escape 키 누르면 frame.reload()로 read-only 행 복귀 (Decision #4)"
    status: failed
    reason: |
      card_form_controller.js:23-25에서 frame.removeAttribute("src") 호출 후
      frame.reload()를 호출한다. Turbo의 reload()는 this.src를 다시 요청하는데,
      removeAttribute("src") 이후 this.src가 빈 문자열이므로 reload()는 사실상 no-op이다.
      read-only 카드 행이 복귀되지 않으며, 편집 폼이 계속 표시된다.
      WR-01로 02-REVIEW.md에도 동일하게 지적되었다.
    artifacts:
      - path: "app/javascript/controllers/card_form_controller.js"
        issue: "line 23: removeAttribute('src') 이후 line 25: frame.reload()는 no-op — src가 없으면 재요청 URL 없음"
    missing:
      - "Escape 핸들러를 수정: 취소 링크 클릭(cancelLink.click()) 방식 또는 frame에 원본 deck_path를 src로 재설정하는 방식으로 교체"

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
**Verified:** 2026-05-30T05:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

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
| 11 | 인라인 편집 frame 안에서 Escape 키 누르면 frame.reload()로 read-only 행 복귀 | FAILED | card_form_controller.js:23-25: removeAttribute("src") 후 reload() 호출 — src가 없으므로 no-op. WR-01 확인 |
| 12 | POST /decks/:id/cards에 front_image 파라미터 포함해도 ActiveStorage attach 안 됨 | VERIFIED | card_params: permit(:front, :back, :hint, :tags)만 허용. 뷰에 image 입력 없음. spec CARD-06 GREEN |
| 13 | 타인 personal 덱 cards 액션 → 403 또는 404 | VERIFIED | CardsController#set_deck: Deck.where(owner: Current.user).find() — 타인 덱은 RecordNotFound(404) |
| 14 | paste import 진입점 페이지가 textarea + 구분자 select + 미리보기 영역과 함께 렌더 | VERIFIED | new.html.erb: paste-import controller, separator select, text textarea, import-preview/actions div 확인 |
| 15 | POST .../imports (mode: preview) → 파싱 결과 테이블이 Turbo Stream으로 갱신 | VERIFIED | create.turbo_stream.erb: turbo_stream.update "import-preview-#{@deck.id}", _preview_table.html.erb 존재 |
| 16 | POST .../imports (mode: save) → 트랜잭션 내 일괄 생성, 한 건 실패 시 전체 롤백 | VERIFIED | PasteImportService: ActiveRecord::Base.transaction + create! + rescue RecordInvalid |
| 17 | 면 내부에 구분자 포함된 줄은 미리보기 빨강 + 저장 차단 | FAILED | parse_line:60의 f.include?(@separator)는 split 후 항상 false — 데드코드. 02-04-SUMMARY "Deferred Issues" 자인 |
| 18 | 덱 내 front 중복 줄은 미리보기 빨강 + 저장 차단 | PARTIAL | DB 기존 중복은 차단. 동일 배치 내 중복은 통과됨 — batch_dupes 로직 없음(grep 0건) |
| 19 | 500장 초과 입력 시 즉시 거부 | VERIFIED | PasteImportService:27 lines.size > IMPORT_LIMIT → failure. IMPORT_LIMIT=500 선언 확인 |
| 20 | 타인 덱 import 진입 시 403 또는 404 | VERIFIED | Cards::ImportsController#set_deck: Deck.where(owner: Current.user).find() + authorize @deck, :update? |
| 21 | deck_params에 owner/scope 미포함 (mass assignment 차단) | VERIFIED | DecksController#deck_params: permit(:title, :description)만 |

**Score:** 18/21 truths verified (2 FAILED, 1 PARTIAL)

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
| `app/services/flashcards/paste_import_service.rb` | 텍스트 파싱 + 검증 + 트랜잭션 | VERIFIED (gaps) | IMPORT_LIMIT=500, transaction+create!, 구분자 충돌 감지는 데드코드 |
| `app/views/decks/index.html.erb` | 3섹션 + 빈 상태 hero | VERIFIED | 3-state 분기 확인, "공식"+"내 덱" 문자열 존재 |
| `app/views/decks/show.html.erb` | 덱 상세 + 카드 테이블 + 진입점 | VERIFIED | id="deck-cards-", id="deck-add-form-", new_deck_cards_imports_path 확인 |
| `app/views/decks/_card_row.html.erb` | Turbo Frame read-only 행 | VERIFIED | turbo_frame_tag "card_#{card.id}", tag: :tr |
| `app/views/decks/_card_edit_form.html.erb` | 인라인 편집 폼 | VERIFIED | data-controller="card-form", keydown->card-form#handleKeydown |
| `app/views/decks/_card_add_form.html.erb` | 신규 카드 추가 폼 + 카운터 | VERIFIED | data-card-form-target="counter", "장 저장됨", data-card-form-saved-count-value |
| `app/views/cards/edit.html.erb` | Turbo Frame 편집 응답 | VERIFIED | turbo_frame_tag "card_#{@card.id}", tag: :tr — ID 일관성 확인 |
| `app/views/cards/create.turbo_stream.erb` | 행 append + 폼 reset | VERIFIED | turbo_stream.append deck-cards-{id} + replace deck-add-form-{id} |
| `app/views/cards/update.turbo_stream.erb` | 단일 행 교체 | VERIFIED | turbo_stream.replace "card_#{@card.id}" |
| `app/views/cards/destroy.turbo_stream.erb` | 행 제거 | VERIFIED | turbo_stream.remove "card_#{@card.id}" |
| `app/views/cards/imports/new.html.erb` | paste import 폼 | VERIFIED | data-controller="paste-import", separator select, text textarea |
| `app/views/cards/imports/_preview_table.html.erb` | 미리보기 테이블 | VERIFIED | import-preview__row--invalid 분기, preview_cards 순회 |
| `app/views/cards/imports/_actions.html.erb` | 저장 버튼 + 카운트 | VERIFIED | importable_count 분기, hidden_field text/separator |
| `app/views/cards/imports/create.turbo_stream.erb` | preview/save Turbo Stream | VERIFIED | turbo_stream.update import-preview + import-actions |
| `app/javascript/controllers/card_form_controller.js` | Cmd+Enter + Escape + 카운터 | PARTIAL | requestSubmit() 확인, Escape no-op 확인됨(WR-01 FAILED) |
| `app/javascript/controllers/paste_import_controller.js` | 구분자 자동 감지 | VERIFIED | static targets=["text","separator"], detectSeparator() 존재 |
| `app/policies/deck_policy.rb` | Pundit policy | VERIFIED | personal_owner?, show? 3분기, Scope=scope.none |
| `config/routes.rb` | decks + nested cards + imports | VERIFIED | resources :decks, resources :cards only:[new,create,edit,update,destroy], namespace :cards { resource :imports } |
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
| _card_add_form → card_form_controller | data-card-form-target="counter" | Stimulus value hook | VERIFIED | savedCount value + counter target 선언 일치 |
| _card_edit_form → card_form_controller | Escape → frame.reload() | keydown handler | FAILED | removeAttribute("src") + reload()는 no-op (WR-01) |
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

Step 7b: SKIPPED — 서버 실행 없이 grep/파일 검사로 진행. request spec 결과(457 examples, 0 failures)가 동작 증거로 대체.

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
| CARD-03 | 02-03 | 카드 수정 (인라인 편집 Turbo Frame) | SATISFIED (partial) | _card_row turbo_frame + edit.html.erb + update.turbo_stream. Escape 복귀 broken(WR-01) |
| CARD-04 | 02-03 | 카드 삭제 (CardReview cascade) | SATISFIED | CardsController#destroy + Card has_many :card_reviews, dependent: :destroy |
| CARD-05 | 02-04 | Paste import 미리보기 후 일괄 저장 | PARTIAL | 흐름 전체 동작. 구분자 충돌 감지 dead code(CR-01), 배치 내 중복 미탐지(CR-02) |
| CARD-06 | 02-03 | card_type=basic만 지원, image UI 숨김 | SATISFIED | card_params image 제외, 뷰에 image 입력 없음 |
| HUB-01 | 02-02 | /decks 오늘의 복습 hero | DEFERRED | Phase 5 — REQUIREMENTS.md Traceability 확인 |
| HUB-02 | 02-02 | /decks official/club/personal 그룹 표시 | SATISFIED | index.html.erb 3섹션 분기 |
| HUB-03 | 02-02 | 0개 덱 사용자 빈 상태 hero + CTA | SATISFIED | index.html.erb:4-26 빈 상태 분기 |
| NAV-01 | 02-02 | 유틸리티 dropdown에 낱말카드 링크 | SATISFIED | application.html.erb line 179 확인 |

DECK-02(site_admin official 생성), DECK-03(club 덱 생성), DECK-08(featured_at 토글)는 REQUIREMENTS.md에 Phase 4로 매핑됨 — 본 phase 범위 외.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/services/flashcards/paste_import_service.rb` | 60 | `f.include?(@separator)` — 논리적 데드코드 (split 후 항상 false) | BLOCKER | 구분자 충돌 감지 기능 무력화 |
| `app/views/decks/index.html.erb` | 20 | "붙여넣기 가져오기" 버튼 → new_deck_path (import 라우트 아님) | WARNING | 사용자 기대와 실제 행동 불일치 |
| `config/routes.rb` | 38 | :new 라우트 선언 + CardsController에 def new 없음 | WARNING | 잠재적 500 오류 (현재 링크 없어 미발생) |
| `spec/requests/cards/imports_spec.rb` | 8 | 로컬 sign_in 재정의 — request_helpers.rb와 중복 | INFO | 장기적 diverge 위험 |

---

## Gaps Summary

### 3개 Blocker/Partial Gap이 Phase 목표 달성을 저해합니다

**CR-01 (BLOCKER): 구분자 충돌 감지 데드코드**

`paste_import_service.rb:56`에서 `line.split(@separator, -1)`이 구분자를 분리하므로, `parse_line:60`의 `f.include?(@separator)` 검사는 항상 false를 반환합니다. 구분자를 포함한 내용이 경고 없이 저장됩니다. 팀 스스로 02-04-SUMMARY "Deferred Issues" 섹션에서 인지했으나 수정 없이 출시했습니다.

**수정**: `parts.size > 4` 조건으로 교체하여 열 수 초과로 구분자 충돌 감지.

**CR-02 (PARTIAL): 배치-내부 front 중복 미감지**

`PasteImportService.call`이 DB 기존 front와의 중복만 검사합니다. 동일 배치 내 두 행이 같은 `front` 값이면 둘 다 `importable?=true`가 되어 모두 저장됩니다. `(deck_id, front)` DB 유니크 제약도 없습니다.

**수정**: DB 쿼리 전에 `batch_fronts.group_by(&:itself).select{|_,v|v.size>1}.keys.to_set` 패턴으로 배치 내 중복 감지 추가.

**WR-01 (BLOCKER): Escape 키 카드 행 복귀 불가**

`card_form_controller.js:23-25`에서 `frame.removeAttribute("src")` 후 `frame.reload()`를 호출하나, Turbo `reload()`는 `this.src`를 재요청하는데 src가 제거된 후라 no-op입니다. 편집 폼이 계속 표시되며 Escape로 read-only 행 복귀가 불가합니다.

**수정**: 취소 링크 클릭 방식(`cancelLink.click()`)으로 교체하거나, frame src를 `deck_path(deck)`로 직접 설정.

---

### 권고사항

1. CR-01과 CR-02를 함께 수정하는 패치 계획 수립
2. WR-01을 card_form_controller.js Escape 핸들러 수정으로 해결
3. WR-02(빈 상태 CTA 라우트)는 UX 의도 확인 후 버튼 텍스트 변경 또는 auto-create 흐름 구현
4. WR-03(:new 라우트)은 routes.rb에서 :new 제거 또는 CardsController에 def new 추가

---

_Verified: 2026-05-30T05:00:00Z_
_Verifier: Claude (gsd-verifier)_
