# Phase 2: Deck + Card CRUD — Research

**Researched:** 2026-05-30
**Domain:** Rails 8.1 Hotwire CRUD (Turbo Frame 인라인 편집, Paste Import, /decks Hub)
**Confidence:** HIGH (코드베이스 직접 확인 + Phase 1 결과물 검증 완료)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

1. **단일 카드 폼 키보드 UX** — `Cmd+Enter`로 저장+다음. 일반 `Enter`는 textarea에서 줄바꿈. 저장 성공 후 form reset + `front` 자동 포커스 + 카운터 표시. `card_type` 항상 `basic`, hidden 처리.
2. **Paste Import UX** — 구분자 자동 감지(Tab > Pipe > Dash) + 명시적 확인 + 수동 오버라이드. 미리보기 테이블(서버 사이드). 구분자 충돌/front 중복 시 저장 차단. 트랜잭션 롤백.
3. **/decks Hub 레이아웃** — 섹션 헤더 + 단일 수직 스크롤. Hero(Phase 5 placeholder) → 공식 덱 → 클럽 덱(소속 클럽 있을 때만) → 내 덱. 덱 카드: 제목/카드 수/scope 배지/마지막 수정일. 학습 버튼·fork 버튼 비노출.
4. **인라인 카드 편집** — 행 전체 클릭 → Turbo Frame 교체 → inline form. `<tr id="card_{id}">` 범위. 저장 성공: Turbo Stream으로 read-only 행 교체 + 토스트. 삭제: 편집 모드 안 "삭제" 버튼 + confirm.
5. **/decks 빈 상태 UX** — "낱말카드로 학습을 시작해 보세요" hero + "내 덱 만들기" CTA + "붙여넣기 가져오기" CTA + 공식 덱 3개 프리뷰.
6. **이미지 첨부 필드 UI** — 완전 숨김. `front_image`/`back_image` strong params에서 명시적 제외. request spec으로 강제 검증.

### Carryforward (Phase 1 잠금)

- `DeckPolicy::Scope#resolve = scope.none` — `policy_scope(Deck)` 절대 사용 금지.
- 어떤 Phase 2 컨트롤러도 `policy_scope(Deck)` 호출 금지 → 명시적 `Deck.where(owner: Current.user)` 등 사용.
- `authorize @deck` 호출은 OK — `personal_owner?` 정책이 동작.
- Phase 1 TODO 마커(phase-4, phase-5) 건드리지 않음.

### Claude's Discretion

- Paste import 최대 카드 수: 500장 권장 (MemberRecords::ImportService::IMPORT_LIMIT 선례).
- 모바일 Cmd+Enter 대안: 항상 노출되는 "저장하고 다음" 버튼 primary, 키보드 단축키는 supplement.
- 클럽 덱 섹션 트리거: approved ClubMembership이 1개 이상일 때 섹션 표시, 클럽 덱 0개면 섹션 내부에 placeholder.

### Deferred Ideas (OUT OF SCOPE)

- 이미지 업로드 UX (v2+)
- Fork 버튼 UI (Phase 4)
- 클럽 덱 생성 UX (Phase 4)
- 공식 덱 모더레이션 UI (Phase 4+)
- Featured toggle (Phase 4)
- 학습 시작 버튼 / SRS loop (Phase 3)
- Due-count badge / streak / mastery (Phase 5)
- 카드 정렬/필터 tags별 (Phase 5+)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DECK-01 | 인증된 사용자가 personal 덱을 생성할 수 있다 | DecksController#new/#create, DeckPolicy#create? 확인됨 |
| DECK-02 | 덱 제목·설명 편집 가능 | DecksController#edit/#update, `authorize @deck` (personal_owner?) |
| DECK-03 | 덱 삭제 가능 (카드 cascade) | dependent: :destroy 확인됨 (Phase 1), Pundit authorize |
| DECK-04 | /decks 허브 — 공식·클럽·개인 3섹션 표시 | 명시적 scope 쿼리 3종 (policy_scope 사용 불가) |
| DECK-05 | 덱 카드에 제목/카드수/scope 배지/수정일 표시 | 뷰 partial에서 render |
| DECK-06 | 클럽 덱 섹션 — approved 멤버십 기준 조건부 표시 | `Current.user.club_memberships.approved.pluck(:club_id)` |
| DECK-07 | 빈 상태 hero (0 personal 덱 사용자) | 조건부 렌더 in index view |
| DECK-08 | 공식 덱 read-only 표시 | authorize 통과, 편집 버튼 숨김 |
| DECK-09 | 유틸리티 nav에 "낱말카드" 메뉴 진입점 추가 | application.html.erb line 172~179 수정 |
| CARD-01 | 카드 단일 추가 폼 (front/back/hint/tags) | DecksController#show 하단 또는 CardsController#new |
| CARD-02 | 저장+다음 Cmd+Enter 키보드 UX | `card_form_controller.js` Stimulus 신규 작성 |
| CARD-03 | 인라인 카드 편집 (행 클릭 → Turbo Frame) | `turbo_frame_tag "card_#{card.id}"` 패턴 |
| CARD-04 | 카드 삭제 (편집 모드 내) | Turbo Stream으로 행 제거 |
| CARD-05* | Paste import (구분자 자동 감지 + 미리보기 + 저장) | `Cards::ImportsController` + `Flashcards::PasteImportService` — *ROADMAP Phase 2 범위, REQUIREMENTS.md 트레이서빌리티는 Phase 4 표기 (ID 충돌 주의)* |
| CARD-06 | 이미지 input 경로 완전 차단 (strong params + UI) | strong params에서 제외, request spec 강제 |
| HUB-01 | /decks 허브 3섹션 레이아웃 | DECK-04와 동일 |
| HUB-02 | 덱별 카드 수 표시 | `deck.cards.count` (N+1 주의 — counter_cache 또는 includes) |
| HUB-03 | 빈 상태 온보딩 | DECK-07과 동일 |
| NAV-01 | 유틸리티 nav에 낱말카드 링크 | DECK-09와 동일 |
| NAV-02~04 | 인증 기반 nav 가시성 | `authenticated?` 헬퍼 이미 사용 중 |
| SEED-01 | 3 공식 덱 렌더링 | Phase 1에서 완료, read-only 표시 검증 |
| SEED-02 | draft 카드 필터링 | /decks 표시 시 draft 카드 제외 여부 결정 필요 (아래 Open Questions §7) |
| TEST-02 | request spec + system spec 작성 | Wave 0에서 spec/system/ 디렉토리 생성 필요 |
</phase_requirements>

---

## Summary

Phase 2는 "카드 저작 UX 완성"이 핵심이다. 이미 Phase 1에서 스키마, 모델, 팩토리, Pundit 정책 stub이 모두 준비된 상태이므로 Phase 2는 거의 100% 컨트롤러·뷰·서비스·Stimulus 레이어 작업이다.

코드베이스에는 이미 Turbo Frame 인라인 편집 선례(`app/views/memos/`)와 Turbo Stream 다중 타겟 업데이트 선례(`app/views/manpower_records/`)가 존재한다. Phase 2는 이 패턴을 카드 테이블에 적용하면 된다. 신규 패턴은 Paste Import UI(클라이언트 감지 + 서버 미리보기 + 트랜잭션 저장)와 `card_form_controller.js`의 Cmd+Enter 키보드 단축키뿐이다.

**가장 큰 위험**: `DeckPolicy::Scope#resolve = scope.none` 지뢰. 컨트롤러 어디서든 `policy_scope(Deck)` 호출 시 빈 결과가 반환된다. 모든 Deck/Card 쿼리는 명시적 `Deck.where(owner: Current.user)` 또는 `@deck.cards` 패턴을 써야 한다.

**Primary recommendation:** clubs_controller.rb 패턴을 DecksController 뼈대로 복사하고, memos Turbo Frame 패턴을 카드 행에 적용하며, manpower_records Turbo Stream 패턴을 저장 성공 응답에 적용하라. 코드베이스에 이미 검증된 선례가 세 가지 모두 존재한다.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| /decks Hub 3섹션 렌더 | Backend (Controller) | View (ERB) | 쿼리 3종을 DB에서 수행, view는 렌더만 |
| 인라인 카드 편집 | Browser (Turbo Frame) | Backend (CardsController#edit) | Frame 교체는 클라이언트; 편집 form 렌더는 서버 |
| 저장 성공 행 교체 | Backend (Turbo Stream) | — | 서버가 정확한 HTML 생성 후 replace 지시 |
| Cmd+Enter 키보드 UX | Browser (Stimulus) | — | 순수 클라이언트 이벤트 처리 |
| Paste import 감지 | Browser (Stimulus) | — | 클라이언트에서 textarea 분석 후 구분자 추론 |
| Paste import 미리보기·저장 | Backend (Service + Controller) | — | 유효성 검사·트랜잭션은 서버에서만 |
| Pundit authorize | Backend (Controller) | — | 모든 뮤테이션 액션에서 authorize 호출 |
| 이미지 params 차단 | Backend (Controller) | — | strong params에서 제외 — 클라이언트 신뢰 불가 |

---

## Standard Stack

### Core (이미 Gemfile에 존재 — 추가 설치 불필요)

| Library | Version (확인됨) | Purpose | Why Standard |
|---------|-----------------|---------|--------------|
| Rails 8.1 | 8.1.3 | 프레임워크 | [VERIFIED: Gemfile.lock] |
| Turbo Rails | ~8.x | Turbo Frame/Stream | [VERIFIED: Gemfile.lock] |
| Stimulus Rails | ~1.x | Stimulus 컨트롤러 | [VERIFIED: Gemfile.lock] |
| Pundit | ~2.x | Authorization | [VERIFIED: app/policies/] |
| RSpec Rails | ~7.x | 테스트 | [VERIFIED: spec/spec_helper.rb 존재] |
| Capybara | 3.40.0 | 시스템 테스트 | [VERIFIED: Gemfile.lock] |
| FactoryBot Rails | ~6.x | 테스트 픽스처 | [VERIFIED: spec/factories/] |
| Shoulda Matchers | ~6.x | 매처 | [VERIFIED: spec/support/ 사용 중] |

### No New Gems Required

Phase 2는 기존 스택으로 100% 구현 가능하다. 새 gem 추가 불필요. [VERIFIED: 코드베이스 분석]

---

## Package Legitimacy Audit

신규 gem/npm 패키지 설치 없음 — 이 섹션 해당 없음.

---

## Architecture Patterns

### System Architecture Diagram

```
[Browser]
  User click/keyboard
       |
       v
[Turbo Frame / Stimulus]
  card_form_controller.js   ← Cmd+Enter → requestSubmit()
  paste_import_controller.js ← textarea paste → separator detect → show selectbox
       |
       v (HTTP request with Turbo headers)
[Rails Router]
  /decks              → DecksController#index
  /decks/:id          → DecksController#show
  /decks/:id/cards    → CardsController (nested)
  /decks/:id/cards/imports → Cards::ImportsController
       |
       v
[Controller Layer]
  authorize @deck / @card   ← Pundit (personal_owner? check)
  Deck.where(owner: Current.user)  ← 명시적 scope (policy_scope 금지)
       |
       v
[Service Layer]
  Flashcards::PasteImportService ← parse + validate + transaction save
       |
       v
[Model Layer]
  Deck.create / Card.create / @deck.cards  ← never Card.where(...)
       |
       v
[Response]
  format.html        → redirect_to / render
  format.turbo_stream → turbo_stream.replace("card_#{id}", ...)
```

### Recommended Project Structure (Phase 2 추가분)

```
app/
  controllers/
    decks_controller.rb          # index / show / new / create / edit / update / destroy
    cards_controller.rb          # create / edit / update / destroy (nested under decks)
    cards/
      imports_controller.rb      # new / create (paste import flow)
  services/
    flashcards/
      paste_import_service.rb    # 파싱 + 검증 + 트랜잭션 저장
  views/
    decks/
      index.html.erb             # Hub 3섹션 + 빈 상태 분기
      show.html.erb              # 덱 상세 + 카드 테이블 + 단일 추가 폼
      new.html.erb / edit.html.erb
      _deck.html.erb             # 덱 카드 partial
      _card_row.html.erb         # 카드 테이블 행 (read-only)
      _card_edit_form.html.erb   # 카드 테이블 행 (edit Turbo Frame 내부)
    cards/
      imports/
        new.html.erb             # paste textarea + separator select + 미리보기 테이블
        create.turbo_stream.erb  # 미리보기 결과 교체
app/
  javascript/
    controllers/
      card_form_controller.js    # Cmd+Enter 처리
      paste_import_controller.js # textarea 붙여넣기 감지 + 구분자 추론
spec/
  requests/
    decks_spec.rb
    cards_spec.rb
    cards/
      imports_spec.rb
  system/
    deck_authoring_spec.rb       # Wave 0에서 디렉토리 + 파일 생성 필요
  services/
    flashcards/
      paste_import_service_spec.rb
```

---

## Pattern 1: 인라인 카드 편집 (Turbo Frame Row Swap)

**What:** 카드 테이블 행 전체를 `turbo_frame_tag "card_#{card.id}"`로 감싸고, edit link의 `data-turbo-frame` 속성으로 해당 frame을 타겟팅. edit 응답도 동일한 frame ID로 감싸면 Rails가 자동으로 교체.

**When to use:** 페이지 이동 없이 특정 DOM 조각만 교체할 때.

**Example (코드베이스 확인된 패턴 — `app/views/memos/_memo.html.erb` 기반):**
```erb
<%# _card_row.html.erb — read-only 행 %>
<%= turbo_frame_tag "card_#{card.id}", tag: :tr do %>
  <td><%= card.front %></td>
  <td><%= card.back %></td>
  <td>
    <%= link_to "편집", edit_deck_card_path(deck, card),
        data: { turbo_frame: "card_#{card.id}" } %>
  </td>
<% end %>
```

```erb
<%# cards/edit.html.erb — edit 응답 %>
<%= turbo_frame_tag "card_#{@card.id}", tag: :tr do %>
  <%= render "card_edit_form", card: @card, deck: @deck %>
<% end %>
```
[VERIFIED: app/views/memos/_memo.html.erb + app/views/memos/edit.html.erb 직접 확인]

---

## Pattern 2: 저장 성공 후 Turbo Stream 행 교체 + 토스트

**What:** `respond_to format.turbo_stream` + `update.turbo_stream.erb` 템플릿. 저장 성공 시 해당 행만 read-only partial로 교체하고 toast 컨테이너에 메시지 표시.

**Example (코드베이스 확인된 패턴 — `app/views/manpower_records/` 기반):**
```ruby
# cards_controller.rb#update
def update
  authorize @card
  if @card.update(card_params)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to deck_path(@deck) }
    end
  else
    render turbo_stream: turbo_stream.replace(
      "card_#{@card.id}",
      partial: "card_edit_form",
      locals: { card: @card, deck: @deck }
    ), status: :unprocessable_entity
  end
end
```

```erb
<%# cards/update.turbo_stream.erb %>
<%= turbo_stream.replace "card_#{@card.id}" do %>
  <%= render "card_row", card: @card, deck: @deck %>
<% end %>
```
[VERIFIED: app/controllers/manpower_records_controller.rb + app/views/manpower_records/create.turbo_stream.erb 직접 확인]

---

## Pattern 3: Cmd+Enter Stimulus 컨트롤러

**What:** card_form_controller.js에서 keydown 이벤트를 리스닝하고 `metaKey + Enter`(Mac) 또는 `ctrlKey + Enter`(Windows) 감지 시 `form.requestSubmit()` 호출.

**Example:**
```javascript
// app/javascript/controllers/card_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "front", "counter"]

  connect() {
    this.count = 0
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.element.querySelector("form").requestSubmit()
    }
  }

  onSuccess() {
    this.count++
    this.counterTarget.textContent = `${this.count}장 저장됨`
    this.element.querySelector("form").reset()
    this.frontTarget.focus()
  }
}
```
[ASSUMED: Stimulus requestSubmit() 패턴 — `import_form_controller.js`에서 requestSubmit() 사용 확인됨, keydown 조합은 표준 패턴]

---

## Pattern 4: Paste Import 구분자 자동 감지 (클라이언트)

**What:** paste_import_controller.js에서 textarea `input` 이벤트 리스닝. 처음 5줄을 분석해 Tab, `|`, `==` 중 빈도 가장 높은 구분자를 selectbox에 자동 선택. 사용자가 override 가능.

**Example:**
```javascript
// app/javascript/controllers/paste_import_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "separator", "previewContainer"]

  detectSeparator() {
    const lines = this.textTarget.value.split("\n").slice(0, 5)
    const counts = { "\t": 0, "|": 0, "==": 0 }
    lines.forEach(line => {
      if (line.includes("\t")) counts["\t"]++
      if (line.includes("|")) counts["|"]++
      if (line.includes("==")) counts["=="]++
    })
    const best = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]
    if (best[1] > 0) {
      this.separatorTarget.value = best[0]
    }
  }
}
```
[ASSUMED: 표준 Stimulus + DOM API 패턴]

---

## Pattern 5: 명시적 Deck 쿼리 3종 (policy_scope 사용 금지)

**What:** `DeckPolicy::Scope#resolve = scope.none` 이므로 컨트롤러에서 직접 scope를 명시해야 한다.

**Example:**
```ruby
# app/controllers/decks_controller.rb#index
def index
  @official_decks = Deck.where(scope: :official).order(:created_at)
  @personal_decks = Current.user ? Deck.where(scope: :personal, owner: Current.user).order(updated_at: :desc) : []

  if Current.user
    approved_club_ids = Current.user.club_memberships.approved.pluck(:club_id)
    @club_decks = approved_club_ids.any? ? Deck.where(scope: :club, owner_type: "Club", owner_id: approved_club_ids) : []
    @show_club_section = Current.user.club_memberships.approved.exists?
  else
    @club_decks = []
    @show_club_section = false
  end
end
```
[VERIFIED: app/policies/deck_policy.rb Scope#resolve = scope.none 확인; clubs_controller.rb 명시 스코프 패턴 확인]

---

## Pattern 6: PasteImportService Result 구조

**What:** `app/services/participations/create_service.rb` Struct 패턴 + `member_records/import_service.rb` 트랜잭션 패턴 조합.

**Example:**
```ruby
# app/services/flashcards/paste_import_service.rb
class Flashcards::PasteImportService < ApplicationService
  IMPORT_LIMIT = 500

  ParsedCard = Struct.new(:front, :back, :hint, :tags, :row_index, :warnings, keyword_init: true)
  Result = Struct.new(:success?, :preview_cards, :importable_count, :warnings, :errors, keyword_init: true) do
    def failure? = !success?
  end

  def self.call(**args) = new(**args).call

  def initialize(text:, separator:, deck:, mode: :preview)
    @text = text
    @separator = separator
    @deck = deck
    @mode = mode
  end

  def call
    lines = @text.lines.map(&:chomp).reject(&:blank?)
    return failure("텍스트가 비어 있습니다.") if lines.empty?
    return failure("최대 #{IMPORT_LIMIT}장까지 가져올 수 있습니다.") if lines.size > IMPORT_LIMIT

    parsed = lines.each_with_index.map { |line, i| parse_line(line, i) }
    collision_errors = detect_collisions(parsed)
    return failure(collision_errors.join(", ")) if collision_errors.any?

    if @mode == :save
      save_cards!(parsed.select { |c| c.warnings.empty? })
    else
      Result.new(success?: true, preview_cards: parsed, importable_count: parsed.count { |c| c.warnings.empty? }, warnings: [], errors: [])
    end
  end

  private

  def parse_line(line, i)
    parts = line.split(@separator, -1)
    front, back, hint, tags = parts[0]&.strip, parts[1]&.strip, parts[2]&.strip, parts[3]&.strip
    warnings = []
    warnings << "앞면 또는 뒷면이 비어 있습니다." if front.blank? || back.blank?
    # 구분자 포함 여부 체크
    if [front, back, hint, tags].compact.any? { |f| f.include?(@separator) }
      warnings << "구분자 충돌"
    end
    ParsedCard.new(front:, back:, hint:, tags:, row_index: i + 1, warnings:)
  end

  def detect_collisions(parsed)
    fronts = parsed.map(&:front).compact
    existing = @deck.cards.where(front: fronts).pluck(:front)
    existing.map { |f| "중복 카드: #{f}" }
  end

  def save_cards!(cards)
    ActiveRecord::Base.transaction do
      cards.each do |c|
        @deck.cards.create!(
          front: c.front, back: c.back, hint: c.hint,
          tags: c.tags, card_type: :basic
        )
      end
    end
    Result.new(success?: true, preview_cards: cards, importable_count: cards.size, warnings: [], errors: [])
  rescue ActiveRecord::RecordInvalid => e
    failure(e.message)
  end

  def failure(msg)
    Result.new(success?: false, preview_cards: [], importable_count: 0, warnings: [], errors: [msg])
  end
end
```
[ASSUMED: 서비스 로직 구조 — `participations/create_service.rb` + `member_records/import_service.rb` 패턴 기반]

---

## Pattern 7: Nav 진입점 추가

`app/views/layouts/application.html.erb` line 172~179 — 기존 포모도로/퍼즐 링크 다음에 삽입:

```erb
<%# 기존 포모도로, 퍼즐 다음에 추가 %>
<%= link_to decks_path, class: "nav__dropdown-item" do %>
  <iconify-icon icon="lucide:layers"></iconify-icon>
  <span>낱말카드</span>
<% end %>
```
[VERIFIED: app/views/layouts/application.html.erb lines 158-181 직접 확인]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Turbo Frame 교체 | 직접 fetch + DOM manipulation | `turbo_frame_tag` + Rails respond | Rails/Turbo가 frame 매칭을 자동 처리 |
| 다중 DOM 업데이트 | JS로 여러 요소 수동 업데이트 | `turbo_stream.replace/append` | 서버가 정확한 HTML 생성, 클라이언트 상태 불일치 없음 |
| Authorization 로직 | 컨트롤러 내 if/else 권한 체크 | `authorize @resource` (Pundit) | 정책이 이미 Phase 1에서 구현됨 |
| 트랜잭션 롤백 | 수동 begin/rescue/rollback | `ActiveRecord::Base.transaction` | ActiveRecord가 예외 시 자동 롤백 |
| form submit 인터셉트 | 커스텀 fetch/XHR | `form.requestSubmit()` | Turbo가 requestSubmit을 후킹해 Turbo Stream 처리 |
| 구분자 충돌 탐지 | 직접 문자열 파싱 (뷰에서) | 서버 PasteImportService | 복잡한 엣지케이스(유니코드, 개행, 공백) 서버 처리가 안전 |

**Key insight:** Turbo Frame/Stream은 "서버가 HTML을 생성하고 어디에 넣을지만 알려준다"는 원칙. 클라이언트에서 HTML을 생성하거나 DOM을 직접 조작하는 패턴은 이 아키텍처에서 안티패턴이다.

---

## Anti-Patterns to Avoid

- **`policy_scope(Deck)` 호출**: Phase 1 Scope stub이 `scope.none`이므로 항상 빈 결과. 모든 Deck 쿼리는 명시적 scope 사용.
- **`Card.where(...)` 직접 쿼리**: 반드시 `@deck.cards.where(...)` 사용 — deck 소유권 체인 유지.
- **strong params에 `front_image`/`back_image` 포함**: 모델에 attach 선언이 있어도 사용자 input 경로 차단이 Phase 2 보안 요구사항.
- **`render` without status on validation failure**: Turbo Stream 오류 응답은 반드시 `status: :unprocessable_entity` 필요 (Turbo 422 처리).
- **`infer_spec_type_from_file_location!` 가정**: 이 프로젝트는 해당 설정이 주석 처리됨. 모든 spec에 `type: :request`, `type: :system` 등 명시 필수.
- **ViewComponent 도입**: CONTEXT.md 명시 금지. partials + Turbo Frame 패턴만 사용.

---

## Common Pitfalls

### Pitfall 1: policy_scope(Deck) 지뢰
**What goes wrong:** `@decks = policy_scope(Deck)` → 항상 빈 결과 반환. 페이지는 렌더되지만 덱이 하나도 보이지 않음.
**Why it happens:** `DeckPolicy::Scope#resolve = scope.none` (Phase 1 intentional stub).
**How to avoid:** 명시적 `Deck.where(owner: Current.user)` 사용. `policy_scope` 코드 리뷰에서 거부.
**Warning signs:** /decks index에서 덱 목록이 비어 있는데 DB에는 데이터 있음.

### Pitfall 2: Turbo Frame ID 불일치
**What goes wrong:** read-only 행의 `turbo_frame_tag` ID와 edit 응답의 `turbo_frame_tag` ID가 다르면 페이지 전체가 교체되거나 아무 일도 안 일어남.
**Why it happens:** `"card_#{card.id}"` vs `"card_#{@card.id}"` 등 미세한 차이.
**How to avoid:** `_card_row.html.erb` partial에서 ID 생성 로직을 단일 helper 또는 partial로 일원화. 항상 `"card_#{card.id}"` 형태.
**Warning signs:** 행 클릭 시 전체 페이지 이동, 또는 클릭해도 아무 변화 없음.

### Pitfall 3: Turbo Stream 응답에 status: :unprocessable_entity 누락
**What goes wrong:** 검증 실패 시 `render turbo_stream: ...`만 하면 Turbo가 성공으로 처리해 form이 사라짐.
**Why it happens:** Turbo는 2xx 응답을 성공으로 처리.
**How to avoid:** `render turbo_stream: ..., status: :unprocessable_entity` 항상 명시.
**Warning signs:** 검증 실패 후 에러 메시지 없이 form 사라짐.

### Pitfall 4: Deck Index N+1 — cards count
**What goes wrong:** `@decks.each { |d| d.cards.count }` → N+1 쿼리.
**Why it happens:** cards 연관이 로드되지 않은 상태.
**How to avoid:** `Deck.where(...).includes(:cards)` 또는 `counter_cache: true`. PITFALLS.md §4 참조.
**Warning signs:** rack-mini-profiler에서 쿼리 수가 덱 수에 비례.

### Pitfall 5: requestSubmit() + Turbo 이중 제출
**What goes wrong:** Stimulus에서 `form.submit()`을 쓰면 Turbo가 인터셉트 못해 일반 HTML submit이 됨.
**Why it happens:** `form.submit()`은 submit 이벤트를 발화하지 않음.
**How to avoid:** 반드시 `form.requestSubmit()` 사용 (`import_form_controller.js` 선례 확인됨).
**Warning signs:** 카드 저장 후 전체 페이지 리로드.

### Pitfall 6: Paste import 구분자 충돌 무시
**What goes wrong:** front 텍스트에 구분자 문자가 포함된 경우 파싱이 깨짐 — "front|extra|back" → front="front", back="extra", 나머지 버림.
**Why it happens:** `split(separator, -1)` 첫 두 조각만 사용.
**How to avoid:** PasteImportService에서 `front.include?(separator)` 체크 후 해당 줄 경고 + 저장 차단 (CONTEXT.md Decision #2 참조).
**Warning signs:** 미리보기에서 back 필드가 의도와 다른 값.

### Pitfall 7: `infer_spec_type_from_file_location!` 없음 → spec 타입 누락
**What goes wrong:** `spec/requests/decks_spec.rb`에 `type: :request` 없으면 request spec 헬퍼(`sign_in`, `response.status` 등)가 동작 안 함.
**Why it happens:** Phase 1 Deviation #2 — 해당 설정 주석 처리됨.
**How to avoid:** 모든 spec 최상단 `RSpec.describe ... , type: :request do` 명시.
**Warning signs:** spec 실행 시 `undefined method 'sign_in'` 또는 `NoMethodError`.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `require_authentication` before_action (Rails 8 built-in) |
| V3 Session Management | yes | `Current.session`, session invalidation 기존 구현 |
| V4 Access Control | yes | Pundit `authorize @deck` / `authorize @card` 매 액션 |
| V5 Input Validation | yes | Model validations + PasteImportService 입력 sanitize |
| V6 Cryptography | no | 해당 없음 |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Mass assignment (image params) | Tampering | strong params에서 `front_image`/`back_image` 제외 |
| Unauthorized deck access | Elevation of Privilege | `authorize @deck` (personal_owner? 체크) |
| XSS in card preview | Tampering | ERB auto-escape (`<%= %>` 사용, `raw` 금지) |
| Paste import과도한 입력 | DoS | IMPORT_LIMIT = 500 + text length validation |
| `owner_id/owner_type` form params | Tampering | strong params에서 `owner_id/owner_type` 명시 제외 |
| IDOR (타인 덱 접근) | Elevation of Privilege | `personal_owner?`가 `record.owner == user` 체크 |

---

## Open Questions (Resolution)

### 1. Paste Import 최대 카드 수
**권장안:** 500장. `MemberRecords::ImportService::IMPORT_LIMIT = 500` 선례가 동일 코드베이스에 존재. [VERIFIED: app/services/member_records/import_service.rb]

### 2. /decks/:id/study 진입 버튼
**권장안:** Phase 2에서 완전 비노출. CONTEXT.md Decision #3 명시 — "학습 시작 버튼은 Phase 3". placeholder 없이 버튼 자체 없음.

### 3. 모바일 Cmd+Enter 대안
**권장안:** 폼 submit 버튼을 "저장하고 다음" 텍스트로 명시하고 항상 노출. Cmd+Enter는 desktop 보조 단축키로 취급. 별도 viewport 분기 불필요 — 버튼이 primary, 단축키가 supplement.

### 4. 클럽 섹션 정확한 트리거
**권장안:** `Current.user.club_memberships.approved.exists?`가 true일 때 섹션 표시. 섹션이 표시되더라도 클럽 덱이 0개면 섹션 내부에 "아직 클럽 덱이 없어요" placeholder 표시. 멤버십 0개면 섹션 자체 숨김.

---

## Runtime State Inventory

Phase 2는 신규 기능 추가(greenfield 컨트롤러/뷰/서비스 레이어)이므로 rename/migration 해당 없음. 해당 섹션 생략.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby 3.3 | Rails 서버 | ✓ | 3.3.11 | — |
| Rails 8.1 | 프레임워크 | ✓ | 8.1.3 | — |
| RSpec | 테스팅 | ✓ | ~7.x | — |
| Capybara | 시스템 테스트 | ✓ | 3.40.0 | — |
| selenium-webdriver | 시스템 테스트 | ✓ | installed | — |
| spec/system/ 디렉토리 | 시스템 테스트 파일 저장 | ✗ | — | Wave 0에서 mkdir 필요 |

**Missing dependencies with no fallback:** 없음.
**Missing dependencies with fallback:** `spec/system/` 디렉토리 미존재 → Wave 0 task에서 `mkdir -p spec/system` + support 파일 생성.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | RSpec ~7.x |
| Config file | `spec/spec_helper.rb`, `spec/rails_helper.rb` |
| Quick run command | `bundle exec rspec spec/requests/decks_spec.rb spec/services/flashcards/paste_import_service_spec.rb` |
| Full suite command | `bundle exec rspec` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DECK-01 | POST /decks 생성 성공/실패 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| DECK-02 | PATCH /decks/:id 업데이트 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| DECK-03 | DELETE /decks/:id + cascade | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| DECK-04 | GET /decks 3섹션 렌더 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| DECK-06 | 클럽 섹션 조건부 표시 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| DECK-07 | 빈 상태 hero 표시 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| DECK-09 | nav 링크 존재 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| CARD-01 | POST /decks/:id/cards 생성 | request | `bundle exec rspec spec/requests/cards_spec.rb` | ❌ Wave 0 |
| CARD-03 | PATCH inline edit Turbo Frame | system | `bundle exec rspec spec/system/deck_authoring_spec.rb` | ❌ Wave 0 |
| CARD-04 | DELETE 카드 Turbo Stream 행 제거 | request | `bundle exec rspec spec/requests/cards_spec.rb` | ❌ Wave 0 |
| CARD-05 | POST /decks/:id/cards/imports preview + save | request | `bundle exec rspec spec/requests/cards/imports_spec.rb` | ❌ Wave 0 |
| CARD-06 | image params 차단 (422 또는 무시) | request | `bundle exec rspec spec/requests/cards_spec.rb` | ❌ Wave 0 |
| SEED-01 | 공식 덱 3개 렌더 | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ Wave 0 |
| TEST-02 | 인증+인가 request spec | request | `bundle exec rspec spec/requests/` | ❌ Wave 0 |

**Sampling Rate:**
- Per task commit: `bundle exec rspec spec/requests/decks_spec.rb --fail-fast`
- Per wave merge: `bundle exec rspec spec/requests/ spec/services/ --fail-fast`
- Phase gate: `bundle exec rspec` 전체 그린 후 `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `spec/system/` 디렉토리 생성 (`mkdir -p spec/system`)
- [ ] `spec/system/deck_authoring_spec.rb` — 인라인 편집 시스템 테스트 (Capybara)
- [ ] `spec/requests/decks_spec.rb` — CRUD + 인증 + 인가 + 3섹션 검증
- [ ] `spec/requests/cards_spec.rb` — 카드 CRUD + image params 차단
- [ ] `spec/requests/cards/imports_spec.rb` — paste import preview/save
- [ ] `spec/services/flashcards/paste_import_service_spec.rb` — 서비스 단위 테스트
- [ ] `spec/support/system_test_helpers.rb` — Capybara 드라이버 설정 (spec/support/ 디렉토리 존재하나 파일 없음 — VERIFIED)
- [ ] `spec/support/request_helpers.rb` — sign_in 헬퍼 이미 존재하는지 확인 후 없으면 생성 (VERIFIED: spec/support/ 비어 있음)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `respond_to :js` + jQuery AJAX | Turbo Frame/Stream | Rails 7+ Hotwire | 별도 JS 불필요, 서버 HTML이 곧 업데이트 |
| `controller_spec` | `request spec` | Rails 5+ 권장 | 실제 HTTP 스택 통과 → 더 현실적 테스트 |
| `before_filter` | `before_action` | Rails 5+ | 동일 기능, 이름 변경 |
| `protect_from_forgery` 수동 | Turbo CSRF 자동 처리 | Rails 7+ | Turbo가 meta tag에서 CSRF 토큰 자동 추출 |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Paste import 최대 500장 | Open Questions §1 | 너무 많으면 성능 이슈, 너무 적으면 UX 불편. 500은 선례 기반 |
| A2 | `card_form_controller.js` keydown 패턴 | Pattern 3 | 실제 Stimulus 버전 API 변경 시 수정 필요 (현재 프로젝트 Stimulus 버전 확인 권장) |
| A3 | PasteImportService `tags:` 필드명 | Pattern 6 | VERIFIED: `db/schema.rb` + `app/models/card.rb` 확인 — `tags` string column (acts_as_taggable 없음). 예제 코드 `tags: c.tags`로 수정 완료. |
| A4 | `spec/support/` 디렉토리 내 파일 없음 | Wave 0 Gaps | VERIFIED: `ls spec/support/` 결과 빈 디렉토리 확인. Wave 0에서 `spec/support/system_test_helpers.rb` 및 `spec/support/request_helpers.rb` 복사/생성 필요. |

---

## Sources

### Primary (HIGH confidence)
- `app/policies/deck_policy.rb` — `Scope#resolve = scope.none`, `personal_owner?` 직접 확인
- `app/policies/card_policy.rb` — DeckPolicy 위임 구조 직접 확인
- `app/controllers/clubs_controller.rb` — 명시적 scope 쿼리 패턴 직접 확인
- `app/controllers/manpower_records_controller.rb` — Turbo Stream respond_to 패턴 직접 확인
- `app/views/memos/_memo.html.erb` + `app/views/memos/edit.html.erb` — Turbo Frame 인라인 편집 패턴 직접 확인
- `app/views/layouts/application.html.erb` lines 158-181 — nav 구조 직접 확인
- `app/services/participations/create_service.rb` — Result Struct 패턴 직접 확인
- `app/services/member_records/import_service.rb` — IMPORT_LIMIT = 500, 트랜잭션 패턴 직접 확인
- `app/javascript/controllers/import_form_controller.js` — `requestSubmit()` 패턴 직접 확인
- `.planning/phases/01-foundations/01-01-SUMMARY.md` — Phase 1 완료 상태, `infer_spec_type_from_file_location!` 주석 처리 확인
- `spec/support/request_helpers.rb` — `sign_in` 헬퍼 구현 직접 확인

### Secondary (MEDIUM confidence)
- `.planning/research/PITFALLS.md` — Pitfall 4 (N+1), Pitfall 6 (구분자 충돌) 패턴
- `.planning/ROADMAP.md` lines 89~140 — Phase 2 success criteria + test surface 목록

### Tertiary (LOW confidence / ASSUMED)
- `card_form_controller.js` 구현 스켈레톤 — 코드베이스 패턴 기반 추론
- `paste_import_controller.js` 구현 스켈레톤 — 표준 Stimulus + DOM API 기반 추론

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — 모든 라이브러리 Gemfile.lock/코드베이스 직접 확인
- Architecture: HIGH — 코드베이스 3개 선례 패턴 직접 확인
- Pitfalls: HIGH — Phase 1 SUMMARY + PITFALLS.md + 정책 코드 직접 확인
- Service 구현: MEDIUM — 패턴은 확인됨, 실제 Card 모델 필드명 일부 ASSUMED

**Research date:** 2026-05-30
**Valid until:** 2026-07-01 (Rails 8.1 안정 버전, 60일)

---

## CARD-05 ID 충돌 주의 (Planner 필독)

`REQUIREMENTS.md` 트레이서빌리티 테이블(line ~245)은 `CARD-05 | Phase 4 | Pending`으로 표기하지만, `ROADMAP.md` Phase 2 scope는 `Cards::ImportsController` + `Flashcards::PasteImportService`를 명시적으로 포함한다.

**Researcher 권장:** ROADMAP Phase 2 scope가 더 최근의 의도를 반영하므로 paste import를 Phase 2에 포함. REQUIREMENTS.md의 CARD-05 Phase 표기는 오래된 것으로 간주하고 planner가 트레이서빌리티 테이블을 Phase 2로 업데이트하거나, paste import 요구사항을 별도 ID(예: IMPORT-01)로 추적하는 방안 중 선택.
