# Phase 2: Deck + Card CRUD — Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 23 (신규 생성 파일 기준)
**Analogs found:** 21 / 23 (exact: 12, role-match: 5, partial-match: 4, no analog: 2)

---

## File Classification

| 신규/수정 파일 | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `app/controllers/decks_controller.rb` | controller | CRUD + request-response | `app/controllers/flash_meetups_controller.rb` | exact |
| `app/controllers/cards_controller.rb` | controller | CRUD + turbo_stream | `app/controllers/club_memberships_controller.rb` | exact |
| `app/controllers/cards/imports_controller.rb` | controller | request-response + service 위임 | `app/controllers/member_records_controller.rb` (#import 액션) | role-match |
| `app/services/flashcards/paste_import_service.rb` | service | transform + batch | `app/services/participations/create_service.rb` + `app/services/member_records/import_service.rb` | role-match |
| `app/views/decks/index.html.erb` | view | CRUD index | `app/views/clubs/index.html.erb` | role-match |
| `app/views/decks/show.html.erb` | view | show + inline form + child rows | `app/views/manpower_records/index.html.erb` | exact |
| `app/views/decks/new.html.erb` | view | form page | `app/views/flash_meetups/new.html.erb` | exact |
| `app/views/decks/edit.html.erb` | view | form page | `app/views/flash_meetups/new.html.erb` | exact |
| `app/views/decks/_form.html.erb` | partial (form) | form fields | `app/views/flash_meetups/_form.html.erb` | exact |
| `app/views/decks/_deck.html.erb` | partial | item card | `app/views/clubs/index.html.erb` (cl-card 패턴) | role-match |
| `app/views/decks/_card_row.html.erb` | partial | Turbo Frame 행 (read-only) | `app/views/memos/_memo.html.erb` | exact |
| `app/views/decks/_card_edit_form.html.erb` | partial | Turbo Frame 행 (edit 폼) | `app/views/memos/edit.html.erb` | exact |
| `app/views/decks/_card_add_form.html.erb` | partial | 하단 고정 새 카드 추가 폼 | `app/views/manpower_records/_form.html.erb` 구조 | role-match |
| `app/views/cards/update.turbo_stream.erb` | turbo_stream | single row replace | `app/views/manpower_records/update.turbo_stream.erb` | exact |
| `app/views/cards/destroy.turbo_stream.erb` | turbo_stream | row remove | `app/views/manpower_records/destroy.turbo_stream.erb` | exact |
| `app/views/cards/imports/new.html.erb` | view | form + preview | (없음) | no analog |
| `app/views/cards/imports/create.turbo_stream.erb` | turbo_stream | preview + form reset | `app/views/manpower_records/create.turbo_stream.erb` | exact |
| `app/javascript/controllers/card_form_controller.js` | JS (Stimulus) | keyboard event + form submit | `app/javascript/controllers/import_form_controller.js` | partial-match |
| `app/javascript/controllers/paste_import_controller.js` | JS (Stimulus) | DOM analysis + event | `app/javascript/controllers/team_rows_controller.js` | partial-match |
| `app/views/layouts/application.html.erb` (수정) | view (nav) | 링크 삽입 | 파일 자체 (lines 172–179) | exact |
| `spec/requests/decks_spec.rb` | spec | request | `spec/requests/clubs_spec.rb` | exact |
| `spec/requests/cards_spec.rb` | spec | request | `spec/requests/clubs_spec.rb` | exact |
| `spec/requests/cards/imports_spec.rb` | spec | request | `spec/requests/clubs_spec.rb` | exact |
| `spec/services/flashcards/paste_import_service_spec.rb` | spec | unit | `spec/services/flashcards/sm2_service_spec.rb` | exact |
| `spec/system/deck_authoring_spec.rb` | spec | browser (Capybara) | (없음) | no analog |

---

## Pattern Assignments

### `app/controllers/decks_controller.rb` (controller, CRUD)

**Analog:** `app/controllers/flash_meetups_controller.rb`

`FlashMeetupsController`가 `allow_unauthenticated_access` + `before_action :set_*` + `authorize` 패턴을 표준적으로 보여준다. `DecksController`는 거기에 명시적 scope 3종 쿼리(`DeckPolicy::Scope` 우회)를 추가한다.

**Imports/class 선언 패턴** (`app/controllers/flash_meetups_controller.rb` lines 1–5):
```ruby
class FlashMeetupsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_flash_meetup, only: %i[show edit update destroy]
```

**DecksController에서는:**
```ruby
class DecksController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_deck, only: %i[show edit update destroy]
  before_action :authorize_deck!, only: %i[edit update destroy]
```

**Index 명시적 scope 쿼리** (RESEARCH.md Pattern 5 기반 — policy_scope 사용 절대 금지):
```ruby
def index
  @official_decks = Deck.where(scope: :official).order(:created_at)

  if authenticated?
    @personal_decks = Deck.where(scope: :personal, owner: Current.user)
                          .includes(:cards)
                          .order(updated_at: :desc)
    approved_club_ids = Current.user.club_memberships.approved.pluck(:club_id)
    @show_club_section = approved_club_ids.any?
    @club_decks = @show_club_section ?
      Deck.where(scope: :club, owner_type: "Club", owner_id: approved_club_ids)
          .includes(:cards).order(updated_at: :desc) : []
  else
    @personal_decks = []
    @club_decks = []
    @show_club_section = false
  end
end
```

**Create 패턴** (`app/controllers/flash_meetups_controller.rb` lines 22–29):
```ruby
def create
  @flash_meetup = Current.user.flash_meetups.build(flash_meetup_params)
  authorize @flash_meetup
  if @flash_meetup.save
    redirect_to @flash_meetup, notice: "번개모임이 개설되었습니다."
  else
    render :new, status: :unprocessable_entity
  end
end
```

**Deck에서는 owner 설정 방식에 주의** (`scope: :personal`이므로 `owner`가 User):
```ruby
def create
  @deck = Deck.new(deck_params.merge(scope: :personal, owner: Current.user))
  authorize @deck
  if @deck.save
    redirect_to @deck, notice: "덱이 생성되었습니다."
  else
    render :new, status: :unprocessable_entity
  end
end
```

**Strong params — image 완전 차단** (CONTEXT.md Decision #6):
```ruby
def deck_params
  params.require(:deck).permit(:title, :description)
  # owner, scope, owner_id, owner_type 명시 제외
end
```

**set_deck / destroy 패턴** (`app/controllers/flash_meetups_controller.rb` lines 53–54, 46–49):
```ruby
def set_flash_meetup
  @flash_meetup = FlashMeetup.find(params[:id])
end

def destroy
  authorize @flash_meetup
  @flash_meetup.destroy!
  redirect_to flash_meetups_path, notice: "번개모임이 삭제되었습니다."
end
```

---

### `app/controllers/cards_controller.rb` (controller, CRUD + turbo_stream)

**Analog:** `app/controllers/club_memberships_controller.rb`

`ClubMembershipsController`는 이 코드베이스에서 nested resource + `respond_to format.turbo_stream` 패턴의 가장 깔끔한 선례다. `before_action :set_club`으로 부모를 찾고, `@club.club_memberships.build(user: Current.user)`로 자식을 생성한다. `CardsController`는 이 패턴을 그대로 따른다.

**Nested 설정 + before_action** (`app/controllers/club_memberships_controller.rb` lines 1–4):
```ruby
class ClubMembershipsController < ApplicationController
  before_action :set_club

  # set_club = @club = Club.find(params[:club_id])  ← line 48
```

**Cards 버전:**
```ruby
class CardsController < ApplicationController
  before_action :set_deck
  before_action :set_card, only: %i[edit update destroy]

  private

  def set_deck
    @deck = Deck.where(owner: Current.user).find(params[:deck_id])
    # policy_scope(Deck) 사용 금지 — scope.none 반환됨
  end

  def set_card
    @card = @deck.cards.find(params[:id])
    authorize @card
  end
```

**Turbo Stream + HTML dual response** (`app/controllers/club_memberships_controller.rb` lines 12–25):
```ruby
def create
  @membership = @club.club_memberships.build(user: Current.user)
  authorize @membership
  if @membership.save
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @club, notice: "가입 신청이 완료되었습니다." }
    end
  else
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "club-join-#{@club.id}",
          partial: "club_memberships/join_error",
          locals: { club: @club, errors: @membership.errors.full_messages }
        )
      }
      format.html { redirect_to @club, alert: @membership.errors.full_messages.join(", ") }
    end
  end
end
```

**Cards#update 검증 실패 — status 필수** (`app/controllers/manpower_records_controller.rb` lines 53–57):
```ruby
# 검증 실패 시 반드시 status: :unprocessable_entity 지정 (Turbo 422 처리)
render turbo_stream: turbo_stream.replace(
  "card_#{@card.id}",
  partial: "decks/card_edit_form",
  locals: { card: @card, deck: @deck }
), status: :unprocessable_entity
```

**Strong params — image 차단:**
```ruby
def card_params
  params.require(:card).permit(:front, :back, :hint, :tags)
  # front_image, back_image 명시 제외 (CONTEXT.md Decision #6)
  # card_type은 항상 :basic — strong params에서 제외, 컨트롤러에서 고정
end
```

---

### `app/controllers/cards/imports_controller.rb` (controller, service 위임)

**Analog:** `app/controllers/member_records_controller.rb` #import 액션 (lines 52–61) — 단, 별도 네임스페이스 컨트롤러로 추출하는 형태는 이 코드베이스에서 신규 패턴.

**import 액션 패턴** (`app/controllers/member_records_controller.rb` lines 52–61):
```ruby
def import
  authorize :member_record, :import?
  file = params[:import_file]
  return redirect_to member_records_path, alert: "파일을 선택해 주세요." unless file

  result = MemberRecords::ImportService.call(file: file)
  notice = "#{result.imported}명 등록, #{result.skipped}명 동의 미체크로 건너뜀"
  notice += " / 오류 #{result.errors.size}건" if result.errors.any?
  redirect_to member_records_path, notice: notice
end
```

**Cards::ImportsController 구조 (namespaced 신규 패턴):**
```ruby
# app/controllers/cards/imports_controller.rb
class Cards::ImportsController < ApplicationController
  before_action :set_deck

  # GET /decks/:deck_id/cards/imports/new  — textarea + separator select
  def new
    authorize @deck, :update?
  end

  # POST /decks/:deck_id/cards/imports (mode: :preview)
  # POST /decks/:deck_id/cards/imports?commit=save (mode: :save)
  def create
    authorize @deck, :update?
    mode = params[:commit] == "저장" ? :save : :preview
    @result = Flashcards::PasteImportService.call(
      text: params[:text],
      separator: params[:separator],
      deck: @deck,
      mode: mode
    )
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to deck_path(@deck) }
    end
  end

  private

  def set_deck
    @deck = Deck.where(owner: Current.user).find(params[:deck_id])
  end
end
```

---

### `app/services/flashcards/paste_import_service.rb` (service, transform + batch)

**Primary analog:** `app/services/participations/create_service.rb` (Result Struct 패턴)
**Secondary analog:** `app/services/member_records/import_service.rb` (IMPORT_LIMIT, 트랜잭션 패턴)

**중요:** `ApplicationService` 기반 클래스는 이 코드베이스에 존재하지 않는다 (`app/services/application_service.rb` 없음). 모든 서비스는 plain Ruby class다. `.claude/rules/services.md`의 `< ApplicationService` 지시는 실제 코드와 불일치한다. **실제 선례를 따를 것.**

**Result Struct 패턴** (`app/services/participations/create_service.rb` lines 1–5):
```ruby
module Participations
  class CreateService
    Result = Struct.new(:success?, :participation, :errors, keyword_init: true)

    def self.call(**args) = new(**args).call
```

**IMPORT_LIMIT + 트랜잭션 패턴** (`app/services/member_records/import_service.rb` lines 1–6):
```ruby
module MemberRecords
  class ImportService
    IMPORT_LIMIT = 500
    Result = Struct.new(:imported, :skipped, :errors, keyword_init: true)

    def self.call(file:)
      new(file).call
    end
```

**PasteImportService 패턴 (위 둘 조합):**
```ruby
# app/services/flashcards/paste_import_service.rb
module Flashcards
  class PasteImportService
    IMPORT_LIMIT = 500

    ParsedCard = Struct.new(:front, :back, :hint, :tags, :row_index, :warnings, keyword_init: true)
    Result = Struct.new(:success?, :preview_cards, :importable_count, :warnings, :errors, keyword_init: true) do
      def failure? = !success?
    end

    def self.call(**args) = new(**args).call

    def initialize(text:, separator:, deck:, mode: :preview)
      @text      = text
      @separator = separator
      @deck      = deck
      @mode      = mode
    end

    def call
      # ... parse → validate → preview/save
    end

    private

    def failure(msg)
      Result.new(success?: false, preview_cards: [], importable_count: 0, warnings: [], errors: [msg])
    end
  end
end
```

---

### `app/views/decks/index.html.erb` (view, 3섹션 Hub)

**Analog:** `app/views/clubs/index.html.erb`

clubs/index가 `cl-page` / `cl-hero` / `cl-content` 구조 + 빈 상태 처리를 보여준다. decks/index는 3섹션(공식/클럽/개인) 구조가 추가된다.

**Page/Hero 구조** (`app/views/clubs/index.html.erb` lines 1–16):
```erb
<% content_for :title, "피클볼 클럽" %>

<div class="cl-page">
  <div class="cl-hero">
    <div class="cl-hero__inner">
      <div class="cl-hero__row">
        <div>
          <p class="cl-hero__eyebrow">Club</p>
          <h1 class="cl-hero__title">피클볼 클럽</h1>
          <p class="cl-hero__subtitle">함께 운동하고 성장하는 커뮤니티를 찾아보세요.</p>
        </div>
        <%= link_to new_club_path, class: "btn btn--primary btn--sm" do %>
          <iconify-icon icon="lucide:plus" width="13"></iconify-icon>
          클럽 개설 신청
        <% end %>
      </div>
```

**빈 상태 패턴** (`app/views/clubs/index.html.erb` lines 55–63):
```erb
<% if @clubs.empty? %>
  <div class="cl-empty">
    <div class="cl-empty__icon">
      <iconify-icon icon="lucide:search" width="20"></iconify-icon>
    </div>
    <p class="cl-empty__text">
      <%= @query.present? ? "검색 결과가 없습니다." : "아직 등록된 클럽가 없습니다." %>
    </p>
  </div>
```

---

### `app/views/decks/show.html.erb` (view, 덱 상세 + 카드 테이블 + 인라인 편집)

**Analog:** `app/views/manpower_records/index.html.erb`

이 파일이 **가장 강력한 단일 아날로그**다. "부모 레코드 컨텍스트 + 자식 목록(행 단위 Turbo Frame 편집) + 하단 inline-add 폼 + Turbo Stream으로 다중 타겟 업데이트" 패턴을 완전히 구현한다.

**자식 목록 컨테이너 + ID 패턴** (`app/views/manpower_records/index.html.erb` lines 95–108):
```erb
<%# 자식 레코드 목록 컨테이너 — Turbo Stream이 이 ID를 타겟으로 update %>
<div id="mp-records-<%= date.iso8601 %>" class="mp-records-list">
  <%= render partial: "record_row",
        collection: records,
        as: :manpower_record,
        locals: { date: date } %>
  <% if records.empty? %>
    <p class="mp-records-empty">등록된 내역이 없습니다.</p>
  <% end %>
</div>

<%# inline-add 폼 컨테이너 — Turbo Stream이 저장 성공 후 reset %>
<div id="mp-form-<%= date.iso8601 %>">
  <%= render "form", manpower_record: new_record %>
</div>
```

**decks/show에서의 대응 구조:**
```erb
<%# 카드 테이블 컨테이너 %>
<div id="deck-cards-<%= @deck.id %>" class="deck-cards">
  <table>
    <tbody>
      <%= render partial: "decks/card_row",
            collection: @cards,
            as: :card,
            locals: { deck: @deck } %>
    </tbody>
  </table>
</div>

<%# 단일 카드 추가 폼 %>
<div id="deck-add-form-<%= @deck.id %>"
     data-controller="card-form">
  <%= render "decks/card_add_form", deck: @deck, card: Card.new %>
</div>
```

---

### `app/views/decks/new.html.erb` + `app/views/decks/edit.html.erb` (view, form page)

**Analog:** `app/views/flash_meetups/new.html.erb`

`cl-page` > `cl-content--form` > `cl-form-card` > `render "form"` 의 4단 감싸기가 이 코드베이스의 표준 form 페이지 구조다. new와 edit은 동일한 레이아웃을 공유하고 eyebrow 텍스트만 다르다.

**전체 페이지 구조** (`app/views/flash_meetups/new.html.erb` lines 1–16):
```erb
<% content_for :title, "운동모임 개설" %>
<div class="cl-page">
  <div class="cl-content cl-content--form">
    <div style="margin-bottom:32px;">
      <p class="cl-hero__eyebrow">
        <%= link_to "운동모임", flash_meetups_path %>
        <span class="sep">/</span> 개설
      </p>
      <h1 class="cl-hero__title">운동모임 개설</h1>
    </div>
    <div class="cl-form-card">
      <%= render "form", flash_meetup: @flash_meetup %>
    </div>
  </div>
</div>
```

**decks/new.html.erb 대응 구조:**
```erb
<% content_for :title, "덱 만들기" %>
<div class="cl-page">
  <div class="cl-content cl-content--form">
    <div style="margin-bottom:32px;">
      <p class="cl-hero__eyebrow">
        <%= link_to "낱말카드", decks_path %>
        <span class="sep">/</span> 새 덱
      </p>
      <h1 class="cl-hero__title">새 덱 만들기</h1>
    </div>
    <div class="cl-form-card">
      <%= render "form", deck: @deck %>
    </div>
  </div>
</div>
```

---

### `app/views/decks/_form.html.erb` (partial, form fields)

**Analog:** `app/views/flash_meetups/_form.html.erb`

`form_with model:` + `cl-form` 클래스 + 에러 표시 블록 + `f.submit persisted? ? "수정" : "만들기"` 패턴.

**핵심 구조** (`app/views/flash_meetups/_form.html.erb` lines 8–13, 85–86):
```erb
<%= form_with model: flash_meetup, class: "cl-form" do |f| %>
  <% if flash_meetup.errors.any? %>
    <div class="cl-form__error">
      <% flash_meetup.errors.full_messages.each do |msg| %><p><%= msg %></p><% end %>
    </div>
  <% end %>
  <%# ... fields ... %>
  <%= f.submit flash_meetup.persisted? ? "수정" : "개설", class: "cl-form__submit" %>
<% end %>
```

**decks/_form.html.erb 적용:**
```erb
<%= form_with model: deck, class: "cl-form" do |f| %>
  <% if deck.errors.any? %>
    <div class="cl-form__error">
      <% deck.errors.full_messages.each do |msg| %><p><%= msg %></p><% end %>
    </div>
  <% end %>
  <div class="cl-form__field">
    <%= f.label :title, "제목", class: "cl-form__label" %>
    <%= f.text_field :title, class: "cl-form__input" %>
  </div>
  <div class="cl-form__field">
    <%= f.label :description, "설명", class: "cl-form__label" %>
    <%= f.text_area :description, class: "cl-form__input", rows: 3 %>
  </div>
  <%= f.submit deck.persisted? ? "수정" : "만들기", class: "cl-form__submit" %>
<% end %>
```

---

### `app/views/decks/_card_row.html.erb` (partial, Turbo Frame 행 — read-only)

**Analog:** `app/views/memos/_memo.html.erb`

`_memo.html.erb`가 이 코드베이스에서 Turbo Frame 인라인 편집의 유일한 완성된 선례다. `turbo_frame_tag "memo_#{memo.id}"` + `link_to edit_path, data: { turbo_frame: "memo_#{memo.id}" }` 패턴을 행(`tr`) 단위로 적용한다.

**전체 파일** (`app/views/memos/_memo.html.erb` lines 1–25):
```erb
<%= turbo_frame_tag "memo_#{memo.id}" do %>
  <div class="memo-card">
    <%# ... content ... %>
    <% if authenticated? && Current.session&.user == memo.user %>
      <div class="memo-card__actions">
        <%= link_to edit_memo_path(memo), class: "memo-card__btn",
            data: { turbo_frame: "memo_#{memo.id}" } do %>
          <iconify-icon icon="lucide:square-pen"></iconify-icon> 수정
        <% end %>
        <%= button_to memo, method: :delete, class: "memo-card__btn memo-card__btn--danger",
            form: { data: { turbo_confirm: "이 메모를 삭제하시겠습니까?" } } do %>
          <iconify-icon icon="lucide:trash"></iconify-icon> 삭제
        <% end %>
      </div>
    <% end %>
  </div>
<% end %>
```

**_card_row.html.erb — tr 단위 적용:**
```erb
<%= turbo_frame_tag "card_#{card.id}", tag: :tr do %>
  <td><%= card.front %></td>
  <td><%= card.back %></td>
  <td><%= card.hint %></td>
  <td><%= card.tags %></td>
  <td>
    <%= link_to "편집", edit_deck_card_path(deck, card),
        data: { turbo_frame: "card_#{card.id}" } %>
  </td>
<% end %>
```

**edit 응답 (`cards/edit.html.erb`):**
```erb
<%= turbo_frame_tag "card_#{@card.id}", tag: :tr do %>
  <%= render "decks/card_edit_form", card: @card, deck: @deck %>
<% end %>
```

**Pitfall 경고:** `"card_#{card.id}"` vs `"card_#{@card.id}"` ID 불일치 시 페이지 전체 교체 발생. partial과 edit 응답에서 동일한 ID 생성 로직을 사용할 것.

---

### `app/views/decks/_card_edit_form.html.erb` (partial, Turbo Frame 행 — edit 폼)

**Analog:** `app/views/memos/edit.html.erb`

memos/edit.html.erb가 이 코드베이스에서 Turbo Frame 편집 응답의 유일한 완성된 선례다. Turbo Frame 태그 안에 폼을 렌더링하는 동일한 패턴을 card 행 편집에 적용한다. `_card_row.html.erb`가 read-only 버전이라면, 이 partial은 같은 Turbo Frame ID 안에서 렌더링되는 edit 버전이다.

**전체 파일** (`app/views/memos/edit.html.erb` lines 1–8):
```erb
<%= turbo_frame_tag "memo_#{@memo.id}" do %>
  <div class="memo-card memo-card--editing">
    <div class="memo-card__accent" style="background: <%= @memo.accent_color %>;"></div>
    <div class="memo-card__body">
      <%= render "form", memo: @memo %>
    </div>
  </div>
<% end %>
```

**_card_edit_form.html.erb — tr 단위 인라인 편집 폼:**
```erb
<%# 이 partial은 turbo_frame_tag "card_#{card.id}", tag: :tr 안에서 렌더링됨 %>
<%# cards/edit.html.erb 또는 update.turbo_stream.erb에서 호출 %>
<td colspan="5">
  <%= form_with model: [deck, card], class: "card-edit-form" do |f| %>
    <% if card.errors.any? %>
      <div class="cl-form__error">
        <% card.errors.full_messages.each do |msg| %><p><%= msg %></p><% end %>
      </div>
    <% end %>
    <div class="card-edit-form__fields">
      <%= f.text_field :front, class: "cl-form__input", placeholder: "앞면" %>
      <%= f.text_field :back, class: "cl-form__input", placeholder: "뒷면" %>
      <%= f.text_field :hint, class: "cl-form__input", placeholder: "힌트 (선택)" %>
    </div>
    <div class="card-edit-form__actions">
      <%= f.submit "저장", class: "btn btn--primary btn--sm" %>
      <%= link_to "취소", deck_card_path(deck, card),
          data: { turbo_frame: "card_#{card.id}" },
          class: "btn btn--ghost btn--sm" %>
    </div>
  <% end %>
</td>
```

---

### `app/views/decks/_card_add_form.html.erb` (partial, 하단 고정 새 카드 추가 폼)

**Analog:** `app/views/manpower_records/index.html.erb` 하단 inline-add 폼 구조

`_card_row.html.erb`가 기존 카드의 read-only 행이라면, 이 partial은 `show.html.erb` 하단에 고정 노출되는 "새 카드 추가" 폼이다. `card-form` Stimulus 컨트롤러가 이 partial을 감싼다. Turbo Stream의 `deck-add-form-#{@deck.id}` 타겟이 저장 후 이 partial을 reset한다.

**manpower_records 하단 폼 패턴** (`app/views/manpower_records/index.html.erb` lines 106–108):
```erb
<div id="mp-form-<%= date.iso8601 %>">
  <%= render "form", manpower_record: new_record %>
</div>
```

**_card_add_form.html.erb 구조:**
```erb
<%# show.html.erb의 deck-add-form-#{deck.id} 컨테이너 안에 렌더링됨 %>
<%# Turbo Stream의 cards/create.turbo_stream.erb가 저장 후 이 폼을 reset %>
<%= form_with model: [deck, card], data: { turbo_stream: "" } do |f| %>
  <% if card.errors.any? %>
    <div class="cl-form__error">
      <% card.errors.full_messages.each do |msg| %><p><%= msg %></p><% end %>
    </div>
  <% end %>
  <div class="card-add-form__row">
    <%= f.text_field :front, placeholder: "앞면",
        class: "cl-form__input",
        data: { card_form_target: "front" } %>
    <%= f.text_field :back, placeholder: "뒷면", class: "cl-form__input" %>
    <%= f.text_field :hint, placeholder: "힌트 (선택)", class: "cl-form__input" %>
    <%= f.submit "추가", class: "btn btn--primary btn--sm" %>
  </div>
<% end %>
```

---

### `app/views/cards/update.turbo_stream.erb` (turbo_stream, row replace)

**Analog:** `app/views/manpower_records/update.turbo_stream.erb`

저장 성공 후 행을 read-only partial로 교체하는 단일 패턴.

**전체 파일** (`app/views/manpower_records/update.turbo_stream.erb` lines 1–14):
```erb
<%= turbo_stream.update "mp-records-#{@request_date.iso8601}" do %>
  <%= render partial: "record_row",
        collection: @records,
        as: :manpower_record,
        locals: { date: @request_date } %>
  <% if @records.empty? %>
    <p class="mp-records-empty">등록된 내역이 없습니다.</p>
  <% end %>
<% end %>

<%= turbo_stream.update "mp-form-#{@request_date.iso8601}" do %>
  <%= render "form", manpower_record: ManpowerRecord.new(request_date: @request_date) %>
<% end %>
```

**cards/update.turbo_stream.erb — 단일 행 교체:**
```erb
<%# 해당 행만 read-only 버전으로 교체 %>
<%= turbo_stream.replace "card_#{@card.id}" do %>
  <%= render "decks/card_row", card: @card, deck: @deck %>
<% end %>
```

---

### `app/views/cards/destroy.turbo_stream.erb` (turbo_stream, row remove)

**Analog:** `app/views/manpower_records/destroy.turbo_stream.erb`

**전체 파일** (`app/views/manpower_records/destroy.turbo_stream.erb` lines 1–13):
```erb
<%= turbo_stream.update "mp-records-#{@request_date.iso8601}" do %>
  <%= render partial: "record_row",
        collection: @records,
        as: :manpower_record,
        locals: { date: @request_date } %>
  <% if @records.empty? %>
    <p class="mp-records-empty">등록된 내역이 없습니다.</p>
  <% end %>
<% end %>
```

**cards/destroy.turbo_stream.erb — 행 직접 제거:**
```erb
<%= turbo_stream.remove "card_#{@card.id}" %>
```

---

### `app/views/cards/imports/create.turbo_stream.erb` (turbo_stream, preview + form reset)

**Analog:** `app/views/manpower_records/create.turbo_stream.erb`

create.turbo_stream.erb가 이 코드베이스에서 "생성 성공 후 목록 갱신 + 폼 reset + 요약 뱃지 갱신"의 3-타겟 업데이트 패턴을 보여준다. imports의 경우 preview 컨테이너 + 저장 버튼 상태 갱신에 응용한다.

**전체 파일** (`app/views/manpower_records/create.turbo_stream.erb` lines 1–21):
```erb
<%# Update records list %>
<%= turbo_stream.update "mp-records-#{@request_date.iso8601}" do %>
  <%= render partial: "record_row",
        collection: @records,
        as: :manpower_record,
        locals: { date: @request_date } %>
  <% if @records.empty? %>
    <p class="mp-records-empty">등록된 내역이 없습니다.</p>
  <% end %>
<% end %>

<%# Reset form %>
<%= turbo_stream.update "mp-form-#{@request_date.iso8601}" do %>
  <%= render "form",
        manpower_record: ManpowerRecord.new(request_date: @request_date) %>
<% end %>

<%# Update trigger summary badge %>
<%= turbo_stream.update "mp-summary-#{@request_date.iso8601}" do %>
  <%= render "day_summary", records: @records %>
<% end %>
```

**cards/imports/create.turbo_stream.erb — preview + 저장 버튼 상태:**
```erb
<%# preview 모드: 파싱 결과 테이블 갱신 %>
<%= turbo_stream.update "import-preview-#{@deck.id}" do %>
  <% if @result.success? %>
    <%= render "cards/imports/preview_table",
          cards: @result.preview_cards,
          deck: @deck %>
  <% else %>
    <div class="cl-form__error">
      <% @result.errors.each do |e| %><p><%= e %></p><% end %>
    </div>
  <% end %>
<% end %>

<%# 저장 버튼 활성화 (importable_count > 0 시) %>
<%= turbo_stream.update "import-actions-#{@deck.id}" do %>
  <%= render "cards/imports/actions",
        deck: @deck,
        importable_count: @result.importable_count %>
<% end %>
```

---

### `app/javascript/controllers/card_form_controller.js` (Stimulus, keyboard + form)

**Analog:** `app/javascript/controllers/import_form_controller.js` (requestSubmit 패턴)

`import_form_controller.js`는 이 코드베이스에서 `requestSubmit()` 사용의 유일한 선례다 (전체 7줄). keydown Cmd+Enter 처리는 이 코드베이스에 선례가 없으나 표준 Stimulus 패턴이다.

**requestSubmit 패턴** (`app/javascript/controllers/import_form_controller.js` lines 1–7):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
    // form.submit() 사용 금지 — Turbo 인터셉트 불가
  }
}
```

**card_form_controller.js — keydown + counter 추가:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["front", "counter"]

  connect() {
    this.count = parseInt(this.element.dataset.savedCount || "0", 10)
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.element.querySelector("form").requestSubmit()
      // requestSubmit() 필수 — form.submit()은 Turbo가 인터셉트 못함
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

---

### `app/javascript/controllers/paste_import_controller.js` (Stimulus, textarea analysis)

**Analog:** `app/javascript/controllers/team_rows_controller.js` (DOM 조작 구조)

textarea 붙여넣기 감지 + 구분자 추론은 이 코드베이스에 선례 없음. `team_rows_controller.js`는 `static targets` + DOM 접근 패턴만 공유한다.

**Stimulus targets + DOM 접근 패턴** (`app/javascript/controllers/team_rows_controller.js` lines 1–5):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template"]

  connect() {
    this.nextIndex = this.rowsTarget.querySelectorAll("[data-team-row]").length
  }
```

**paste_import_controller.js 구조 (RESEARCH.md Pattern 4 기반):**
```javascript
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
    if (best && best[1] > 0) {
      this.separatorTarget.value = best[0]
    }
  }
}
```

---

### `app/views/layouts/application.html.erb` (수정 — nav 진입점)

**수정 위치:** lines 172–179 (유틸리티 dropdown, 포모도로/퍼즐 다음)

**현재 코드** (`app/views/layouts/application.html.erb` lines 172–179):
```erb
<div class="nav__dropdown" data-nav-group-target="dropdown">
  <%= link_to focus_path, class: "nav__dropdown-item" do %>
    <iconify-icon icon="lucide:timer"></iconify-icon><span>포모도로</span>
  <% end %>
  <%= link_to puzzle_path, class: "nav__dropdown-item" do %>
    <iconify-icon icon="lucide:puzzle"></iconify-icon><span>퍼즐조각맞추기</span>
  <% end %>
</div>
```

**추가할 패턴 (기존 item과 동일 구조):**
```erb
<%= link_to decks_path, class: "nav__dropdown-item" do %>
  <iconify-icon icon="lucide:layers"></iconify-icon><span>낱말카드</span>
<% end %>
```

---

### `spec/requests/decks_spec.rb` + `spec/requests/cards_spec.rb` + `spec/requests/cards/imports_spec.rb` (spec, request)

**Analog:** `spec/requests/clubs_spec.rb`

모든 request spec은 동일한 구조를 따른다.

**필수 패턴** (`spec/requests/clubs_spec.rb` lines 1–4):
```ruby
require "rails_helper"

RSpec.describe "Decks", type: :request do
  # type: :request 명시 필수
  # infer_spec_type_from_file_location! 주석 처리됨 (spec/rails_helper.rb line 68)
```

**sign_in 헬퍼 패턴** (`spec/requests/clubs_spec.rb` lines 38–40):
```ruby
context "일반 사용자" do
  let(:user) { create(:user) }
  before { sign_in(user) }
```

`sign_in`은 `spec/support/request_helpers.rb`에 정의됨 (lines 2–4):
```ruby
def sign_in(user)
  post session_path, params: { email_address: user.email_address, password: "password" }
end
```

**인증 차단 테스트 패턴** (`spec/requests/flash_meetups_spec.rb` lines 28–33):
```ruby
describe "GET /flash_meetups/new" do
  it "비로그인 시 리다이렉트" do
    get new_flash_meetup_path
    expect(response).to redirect_to(new_session_path)
  end
```

---

### `spec/services/flashcards/paste_import_service_spec.rb` (spec, unit)

**Analog:** `spec/services/flashcards/sm2_service_spec.rb`

**구조 패턴** (`spec/services/flashcards/sm2_service_spec.rb` lines 1–3):
```ruby
require "rails_helper"

RSpec.describe Flashcards::Sm2Service do
  # type 생략 가능 (describe에 클래스명이면 service spec으로 처리됨)
  # 또는 type: :model 명시
```

**성공/실패 경로 패턴** (`spec/services/flashcards/sm2_service_spec.rb` lines 34–50):
```ruby
describe "fresh card (ease=2.5, interval=0, repetitions=0)" do
  let(:base) { { ease: 2.5, interval_days: 0, repetitions: 0 } }

  {
    1 => { ease: 1.96, interval_days: 1, repetitions: 0 },
    # ...
  }.each do |rating, expected|
    it "rating=#{rating} -> ..." do
      result = described_class.call(**base, rating: rating)
      expect(result.ease).to eq(expected[:ease])
    end
  end
end
```

---

## Shared Patterns

### 인증 (Authentication)

**Source:** `app/controllers/concerns/authentication.rb`
**Apply to:** `DecksController`, `CardsController`, `Cards::ImportsController`

```ruby
# require_authentication은 ApplicationController before_action으로 기본 적용됨.
# 비인증 허용이 필요한 액션만 명시적으로 skip:
allow_unauthenticated_access only: %i[index show]
before_action :resume_session, only: %i[index show]

# Current.user는 authenticated? 시에만 non-nil:
def current_user
  Current.session&.user
end
```

### Pundit Authorization

**Source:** `app/controllers/application_controller.rb` (Pundit::Authorization include)
**Apply to:** 모든 mutating 액션 (create/update/destroy)

```ruby
# ApplicationController line 12 — NotAuthorizedError 전역 처리:
rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

# 모든 액션에서 authorize 호출 패턴:
authorize @deck                        # personal_owner? 체크
authorize @card                        # DeckPolicy 위임
authorize @deck, :update?              # imports_controller

# policy_scope(Deck) 절대 사용 금지 (scope.none 반환)
```

### Turbo Stream 검증 실패 응답

**Source:** `app/controllers/manpower_records_controller.rb` lines 32–38
**Apply to:** `CardsController#create`, `CardsController#update`

```ruby
# 검증 실패 시 반드시 status: :unprocessable_entity 지정
render turbo_stream: turbo_stream.replace(
  "card_#{@card.id}",
  partial: "decks/card_edit_form",
  locals: { card: @card, deck: @deck }
), status: :unprocessable_entity
# status 누락 시 Turbo가 성공으로 처리 → form 사라짐
```

### request spec type 명시

**Source:** `spec/requests/clubs_spec.rb` line 3
**Apply to:** 모든 신규 spec 파일

```ruby
RSpec.describe "Decks", type: :request do  # type: :request 필수
# spec/rails_helper.rb line 68: infer_spec_type_from_file_location! 주석 처리됨
# type 없으면 sign_in 헬퍼 등 request spec 헬퍼 사용 불가
```

### N+1 방지 — includes

**Source:** PITFALLS.md §4 + 코드베이스 관례
**Apply to:** `DecksController#index`

```ruby
# 덱 목록에서 cards.count를 쓸 때 N+1 방지:
@personal_decks = Deck.where(scope: :personal, owner: Current.user)
                      .includes(:cards)            # N+1 방지
                      .order(updated_at: :desc)
# 뷰에서: deck.cards.size  (DB count 쿼리 아닌 preload 사용)
```

---

## 선례 없는 파일 (Patterns Without Strong Precedent — RESEARCH.md 우선 참조)

코드베이스에 동일 역할+데이터 플로우의 선례가 없는 파일. 구조는 위 partial-match 아날로그에서 빌리되, 세부 구현은 RESEARCH.md 패턴을 따른다:

| 파일 | Role | Data Flow | 이유 |
|------|------|-----------|------|
| `app/views/cards/imports/new.html.erb` | view | form + live preview | paste textarea + separator select + preview 테이블 조합은 신규 패턴. RESEARCH.md Pattern 2/4 사용 |
| `spec/system/deck_authoring_spec.rb` | spec | browser (Capybara) | `spec/system/` 디렉토리 미존재 (Wave 0 gap). Capybara 시스템 테스트 선례 없음. Capybara 공식 문서 참조 |

**partial-match 파일 (구조 선례는 있으나 세부 로직은 신규):**

| 파일 | 선례 있는 부분 | 신규 부분 |
|------|--------------|-----------|
| `card_form_controller.js` | `requestSubmit()` ← import_form_controller.js | Cmd+Enter keydown, form reset, 카운터 상태 |
| `paste_import_controller.js` | `static targets` ← team_rows_controller.js | textarea 분석, 구분자 추론 알고리즘 |

---

## 주요 Pitfall 요약 (planner 참조)

1. **`policy_scope(Deck)` = 빈 결과** — Phase 1 Scope stub이 `scope.none`. 모든 Deck 쿼리는 명시적 `Deck.where(owner: Current.user)` 사용.
2. **Turbo Frame ID 불일치** — `"card_#{card.id}"` 를 partial + edit 응답에서 동일하게 사용. helper method로 일원화 권장.
3. **`status: :unprocessable_entity` 누락** — Turbo Stream 검증 실패 응답에 필수.
4. **`form.submit()` 대신 `form.requestSubmit()`** — Stimulus에서 Turbo 인터셉트를 위해 필수.
5. **`type: :request` 누락** — `infer_spec_type_from_file_location!` 주석 처리됨, 모든 spec에 명시 필수.
6. **`ApplicationService` 상속 불가** — `app/services/application_service.rb` 파일 없음. plain class + `self.call(**args) = new(**args).call` 패턴 사용.

---

## Traceability Note

**CARD-05 ID 충돌:** `REQUIREMENTS.md`는 `CARD-05`를 Phase 4로 표기하나 `ROADMAP.md` Phase 2 scope는 `Cards::ImportsController` + `Flashcards::PasteImportService`를 명시 포함한다. Planner가 ID를 `IMPORT-01`로 분리하거나 REQUIREMENTS.md를 Phase 2로 업데이트해야 한다. (RESEARCH.md lines 712–716 참조)

---

## Metadata

**Analog search scope:** `app/controllers/`, `app/views/`, `app/javascript/controllers/`, `app/services/`, `spec/requests/`, `spec/services/`
**Files scanned:** 26개 파일 직접 확인
**Pattern extraction date:** 2026-05-30
