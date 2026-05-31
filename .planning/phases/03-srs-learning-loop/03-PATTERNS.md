# Phase 3: SRS Learning Loop - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 16 (신규/확장 대상)
**Analogs found:** 14 / 16

---

## Phase Override Notes

`.claude/rules/services.md`와 `.claude/rules/controllers.md`의 기본 컨벤션 중 아래 항목은 **Phase 3 결정에 의해 재정의**된다. 플래너는 이 오버라이드를 적용해야 한다.

| 기본 컨벤션 | Phase 3 오버라이드 | 근거 |
|---|---|---|
| `ApplicationService` 상속 | PORO만 사용 (`Struct.new` 패턴) | D-21 |
| `policy_scope(Deck)` 사용 | 명시적 WHERE 절 사용 | D-19 (DeckPolicy::Scope가 `scope.none` 반환 중) |
| `before_action :resume_session` 명시 | `ApplicationController` → `Authentication` concern의 `require_authentication`에 위임 | A2 확인됨 — StudiesController에 없음 |

---

## File Classification

| 신규/수정 파일 | Role | Data Flow | 가장 가까운 Analog | 매칭 품질 |
|---|---|---|---|---|
| `app/controllers/card_reviews_controller.rb` | controller | request-response (Turbo Stream) | `app/controllers/cards_controller.rb` | exact |
| `app/controllers/study_controller.rb` | controller | request-response | `app/controllers/decks/studies_controller.rb` | role-match |
| `app/controllers/decks/studies_controller.rb` | controller | request-response | 자기 자신 (확장만) | self |
| `app/controllers/decks/browses_controller.rb` | controller | request-response | `app/controllers/decks/studies_controller.rb` | role-match |
| `app/services/flashcards/submit_review_service.rb` | service | CRUD | `app/services/participations/create_service.rb` | exact |
| `app/queries/flashcards/global_study_queue_query.rb` | query | CRUD | `app/queries/flashcards/study_queue_query.rb` | exact |
| `app/javascript/controllers/study_session_controller.js` | Stimulus controller | event-driven | `app/javascript/controllers/pomodoro_controller.js` | role-match |
| `app/javascript/controllers/browse_controller.js` | Stimulus controller | event-driven | `app/javascript/controllers/modal_controller.js` | partial |
| `app/views/decks/studies/_card.html.erb` | view partial | request-response | (없음 — 현재 파일이 최소 골격) | no analog |
| `app/views/card_reviews/create.turbo_stream.erb` | turbo stream template | request-response | `app/views/cards/create.turbo_stream.erb` | exact |
| `app/views/study/show.html.erb` | view | request-response | `app/views/decks/studies/show.html.erb` | role-match |
| `app/views/study/complete.html.erb` | view | request-response | `app/views/decks/studies/complete.html.erb` | role-match |
| `app/views/decks/browses/show.html.erb` | view | request-response | `app/views/decks/studies/show.html.erb` | partial |
| `spec/requests/card_reviews_spec.rb` | test | request-response | `spec/requests/cards_spec.rb` | exact |
| `spec/requests/study_spec.rb` | test | request-response | `spec/requests/decks/studies_spec.rb` | exact |
| `spec/requests/decks/browses_spec.rb` | test | request-response | `spec/requests/decks/studies_spec.rb` | role-match |

---

## Pattern Assignments

### `app/controllers/card_reviews_controller.rb` (controller, Turbo Stream)

**Primary Analog:** `app/controllers/cards_controller.rb`
**Secondary Analog:** `app/controllers/participations_controller.rb`

**Imports / 클래스 선언 패턴** (`app/controllers/cards_controller.rb` 전체):
```ruby
# 클래스 선언 — ApplicationController 상속, 인증은 상속 체인에서 자동 적용
class CardsController < ApplicationController
  before_action :set_deck
  before_action :set_card, only: %i[edit update destroy]
```

**Turbo Stream create 패턴** (`app/controllers/cards_controller.rb` lines 5-26):
```ruby
def create
  @card = @deck.cards.build(card_params.merge(card_type: :basic))
  authorize @card                          # Pundit: 반드시 authorize 호출
  if @card.save
    @cards = @deck.cards.order(:position, :id)
    respond_to do |format|
      format.turbo_stream                  # -> views/cards/create.turbo_stream.erb
      format.html { redirect_to deck_path(@deck), notice: "..." }
    end
  else
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "target-id",
          partial: "...",
          locals: { ... }
        ), status: :unprocessable_entity   # 실패 시 422
      }
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

**Service Result 분기 패턴** (`app/controllers/participations_controller.rb` lines 13-32):
```ruby
def create
  @participation = Participation.new
  authorize @participation

  result = Participations::CreateService.call(
    game_session: @game_session,
    user:         Current.user,
    ...
  )

  if result.success?
    redirect_to ..., notice: msg
  else
    flash.now[:alert] = result.errors.join(", ")
    render :new, status: :unprocessable_entity
  end
end
```

**CardReviewsController용 합성 패턴** (위 두 패턴을 결합):
```ruby
class CardReviewsController < ApplicationController
  def create
    @card = Card.find(params[:card_review][:card_id])
    @card_review = CardReview.new(user: Current.user, card: @card)
    authorize @card_review                 # CardReviewPolicy#create? 검증

    result = Flashcards::SubmitReviewService.call(
      user:    Current.user,
      card_id: params[:card_review][:card_id],
      rating:  params[:card_review][:rating].to_i
    )

    @deck = Deck.find(params[:card_review][:deck_id]) if params[:card_review][:deck_id].present?

    if result.success?
      @next_card = @deck ? Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call.first : nil
      respond_to { |f| f.turbo_stream }   # -> views/card_reviews/create.turbo_stream.erb
    else
      respond_to do |f|
        f.turbo_stream { render :error, status: :unprocessable_entity }
      end
    end
  end

  private

  def card_review_params
    params.require(:card_review).permit(:card_id, :rating, :deck_id)
  end
end
```

**Strong params 패턴** (`app/controllers/cards_controller.rb` lines 68-75 — policy_scope 금지 주석 포함):
```ruby
def set_deck
  # policy_scope(Deck) 사용 금지 (scope.none 반환) — 명시적 owner 스코프
  @deck = Deck.where(owner: Current.user).find(params[:deck_id])
end

def card_params
  params.require(:card).permit(:front, :back, :hint, :tags)
  # 명시적 제외: :front_image, :back_image — D-20 유지
end
```

---

### `app/controllers/study_controller.rb` (controller, request-response)

**Analog:** `app/controllers/decks/studies_controller.rb` (lines 1-17)

**골격 패턴** (직접 복사 기반):
```ruby
class Decks::StudiesController < ApplicationController
  before_action :set_deck

  def show
    authorize @deck, :show?
    @due_cards = Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
    if @due_cards.empty?
      render :complete
    end
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
```

**StudyController 변형 패턴:**
```ruby
class StudyController < ApplicationController
  # 네임스페이스 없음 — D-16
  # authorize 호출 대상 없음 — Pundit open question A3 참조
  # GlobalStudyQueueQuery는 자체적으로 접근 제어를 담당 (policy_scope 금지)

  def show
    # skip_authorization or authorize :application, :study?  -- 플래너가 A3 해결
    @due_cards = Flashcards::GlobalStudyQueueQuery.new(user: Current.user).call
    if @due_cards.empty?
      render :complete   # -> views/study/complete.html.erb (deck_path 없음 — D-18)
    end
  end
end
```

> **Pundit A3 경고:** `ApplicationController`에 `after_action :verify_authorized`가 없음이 코드로 확인됨. 그러나 `skip_authorization` 명시 또는 `ApplicationPolicy#study?` 추가 중 어느 방식을 쓸지는 플래너가 결정.

---

### `app/controllers/decks/browses_controller.rb` (controller, request-response)

**Analog:** `app/controllers/decks/studies_controller.rb` (lines 1-17)

**패턴** (studies_controller와 동일 구조):
```ruby
class Decks::BrowsesController < ApplicationController
  before_action :set_deck

  def show
    authorize @deck, :show?
    @cards = @deck.cards.order(:position, :id)
    # CardReview 생성/수정 코드 절대 없음 — D-15 / BROWSE-04
    # @cards를 JSON으로 뷰에 전달 → data-browse-cards-value
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
```

---

### `app/services/flashcards/submit_review_service.rb` (service, CRUD)

**Analog:** `app/services/participations/create_service.rb` (lines 1-35 — 전체)

**PORO + Result Struct 패턴** (exact copy 기반):
```ruby
module Participations
  class CreateService
    Result = Struct.new(:success?, :participation, :errors, keyword_init: true)
    #                  ^^^ 콜론으로 시작하는 key, keyword_init: true 필수

    def self.call(**args) = new(**args).call  # 한 줄 단축 메서드

    def initialize(game_session:, user:, participation_type: :as_member)
      @game_session       = game_session
      @user               = user
      @participation_type = participation_type
    end

    def call
      # 성공 경로
      Result.new(success?: true, participation: participation, errors: [])
      # 실패 경로
      Result.new(success?: false, participation: participation,
                 errors: participation.errors.full_messages)
    end

    private

    def failure(message)
      Result.new(success?: false, participation: nil, errors: [ message ])
    end
  end
end
```

**SM2Service Result Struct 패턴** (`app/services/flashcards/sm2_service.rb` lines 17-19):
```ruby
Result = Struct.new(:ease, :interval_days, :repetitions, :next_review_at, keyword_init: true)

def self.call(**args) = new(**args).call

def initialize(ease:, interval_days:, repetitions:, rating:, now: Time.current)
```

**SubmitReviewService 합성 패턴:**
```ruby
module Flashcards
  class SubmitReviewService
    # ApplicationService 상속 금지 — D-21
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
        ease:          card_review.ease          || 2.5,  # Pitfall 7: nil 기본값 보호
        interval_days: card_review.interval_days || 0,
        repetitions:   card_review.repetitions   || 0
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
      # bare retry 절대 금지 — Pitfall 9 (무한루프)
      begin
        card_review = CardReview.find_by!(user: @user, card_id: @card_id)
        card_review.update!(...)
        Result.new(success?: true, card_review: card_review, errors: [])
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success?: false, card_review: nil, errors: e.record.errors.full_messages)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, card_review: nil, errors: e.record.errors.full_messages)
    end
  end
end
```

> **SM-2 QUALITY_MAP 소스 오브 트루스:** `app/services/flashcards/sm2_service.rb:14`의 실제 코드값 `{1 => 1, 2 => 3, 3 => 4, 4 => 5}` (LOCKED). CONTEXT.md D-22의 값(`{1=>0, 2=>2, 3=>3, 4=>5}`)은 stale — 코드 값을 우선.

---

### `app/queries/flashcards/global_study_queue_query.rb` (query, CRUD)

**Analog:** `app/queries/flashcards/study_queue_query.rb` (lines 1-27 — 전체)

**전체 패턴** (직접 참조):
```ruby
module Flashcards
  class StudyQueueQuery
    NEW_CARD_LIMIT = 10

    def initialize(user:, deck:)      # GlobalStudyQueueQuery는 user: 만 받음
      @user = user
      @deck = deck
    end

    def call
      deck.cards
          .joins(join_clause)
          .where("card_reviews.id IS NULL OR card_reviews.next_review_at IS NULL OR card_reviews.next_review_at <= ?", Time.current)
          .order(Arel.sql("card_reviews.next_review_at ASC NULLS FIRST, cards.position ASC, cards.id ASC"))
          .limit(NEW_CARD_LIMIT)
    end

    private

    attr_reader :user, :deck

    def join_clause
      sanitized_id = ActiveRecord::Base.connection.quote(user.id)
      "LEFT OUTER JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = #{sanitized_id}"
    end
  end
end
```

**GlobalStudyQueueQuery 변형 핵심:**
```ruby
# TODO(phase-4): replace with DeckPolicy::Scope when 3-tier resolver is implemented
accessible_decks = Deck.where(scope: :personal, owner: @user)
                       .or(Deck.where(scope: :official))
# policy_scope(Deck) 절대 사용 금지 — scope.none 반환 (D-19)

Card.where(deck: accessible_decks)
    .joins(join_clause)          # StudyQueueQuery와 동일 join_clause 메서드
    .where("card_reviews.id IS NULL OR ...")
    .order(Arel.sql("card_reviews.next_review_at ASC NULLS FIRST, cards.position ASC, cards.id ASC"))
    .limit(NEW_CARD_LIMIT)
```

---

### `app/javascript/controllers/study_session_controller.js` (Stimulus, event-driven)

**Primary Analog:** `app/javascript/controllers/pomodoro_controller.js` (lines 1-19)
**Secondary Analog:** `app/javascript/controllers/import_form_controller.js` (requestSubmit 패턴)

**connect/disconnect + 이벤트 바인딩 패턴** (`pomodoro_controller.js` lines 13-19):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "startBtn", ...]
  static values  = { focusMinutes: Number, ... }

  connect() {
    this.mode = "focus"
    this._reset()
  }

  disconnect() { this._clearTick(); ... }
}
```

**requestSubmit 패턴** (`import_form_controller.js` lines 4-6):
```javascript
submit() {
  this.element.requestSubmit()
}
```

**study_session_controller.js 핵심 구조:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["back", "showButton", "ratingRow", "ratingButton"]
  // static values 없음 — flip 상태는 this.flipped 인스턴스 변수

  connect() {
    this.flipped = false
    this.handleKeydown = this.handleKeydown.bind(this)  // pomodoro 패턴
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)  // 반드시 해제
  }

  flip() { /* data-flipped=true, back 표시, ratingRow 표시 */ }

  submitRating(event) {
    this.ratingButtonTargets.forEach(btn => { btn.disabled = true })
    // form.requestSubmit() — import_form_controller 패턴
  }

  handleKeydown(event) {
    if (!this.flipped) return  // D-04: flip 전 키 입력 차단
    const map = { "1": 0, "2": 1, "3": 2, "4": 3 }
    const idx = map[event.key]
    if (idx !== undefined) {
      event.preventDefault()
      this.ratingButtonTargets[idx]?.click()
    }
  }
}
```

> **Stimulus mount 경고 (Pitfall 8):** Turbo Stream이 `#study-card` div를 replace할 때, `_card.html.erb` partial의 **최외곽 div에 `data-controller="study-session"`을 포함**해야 Stimulus가 새 DOM에 자동 재연결된다. `#study-card` wrapper 외부에 마운트하면 replace 후 재연결이 발생하지 않는다.

---

### `app/javascript/controllers/browse_controller.js` (Stimulus, event-driven)

**Primary Analog:** `app/javascript/controllers/modal_controller.js` (lines 1-23)
**Secondary Analog:** `app/javascript/controllers/pomodoro_controller.js` (values + 상태 관리)

**static values + connect + 렌더 패턴** (`modal_controller.js` + `pomodoro_controller.js`):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { autoOpen: Boolean }  // modal 패턴 — browse는 cards: Array
  static targets = ["dialog"]

  connect() {
    if (this.autoOpenValue) this.open()  // values API 접근법
  }

  open() {
    if (this.dialogTarget.open) return
    this.dialogTarget.showModal()
  }
}
```

**browse_controller.js 핵심 구조:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { cards: Array }       // Stimulus Value API — data-browse-cards-value
  static targets = ["front", "back", "showButton", "counter", "prevButton", "nextButton"]

  connect() {
    this.currentIndex = 0
    this.shuffled = false
    this.orderedCards = [...this.cardsValue]
    this.displayCards = [...this.orderedCards]
    this.render()
  }

  flip() { /* 답 보기 버튼 — study와 동일 패턴 */ }
  prev() { /* currentIndex-- + render() */ }
  next() { /* currentIndex++ + render() */ }
  toggleShuffle() { /* Fisher-Yates + render() — 서버 요청 없음 */ }

  render() {
    const card = this.displayCards[this.currentIndex]
    this.frontTarget.textContent = card.front
    this.backTarget.textContent = card.back
    this.backTarget.classList.add("hidden")
    this.showButtonTarget.classList.remove("hidden")
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

---

### `app/views/card_reviews/create.turbo_stream.erb` (Turbo Stream template)

**Analog:** `app/views/cards/create.turbo_stream.erb` (lines 1-6)

**기존 패턴** (정확히 참조):
```erb
<%# app/views/cards/create.turbo_stream.erb %>
<%= turbo_stream.append "deck-cards-#{@deck.id}" do %>
  <%= render "decks/card_row", card: @card, deck: @deck %>
<% end %>
<%= turbo_stream.replace "deck-add-form-#{@deck.id}" do %>
  <%= render "decks/card_add_form", deck: @deck, card: Card.new %>
<% end %>
```

**card_reviews용 변형 패턴** (append → replace, 단일 타겟):
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

---

### `app/views/decks/studies/_card.html.erb` (확장 대상)

**현재 파일** (`app/views/decks/studies/_card.html.erb` lines 1-3):
```erb
<div class="bg-white rounded-xl shadow-md p-8 text-center">
  <p class="text-lg text-gray-800"><%= card.front %></p>
</div>
```

> **No analog in codebase.** front + back + 평가 버튼 패턴의 기존 구현이 없음. RESEARCH.md Pattern 4 및 D-01~D-05 결정을 기반으로 작성. 단, **`data-controller="study-session"`은 이 partial의 최외곽 div에** 배치해야 Turbo Stream replace 후 Stimulus 재연결이 작동한다 (Pitfall 8).

---

### `app/views/study/show.html.erb` + `app/views/study/complete.html.erb`

**Analog:** `app/views/decks/studies/show.html.erb` + `app/views/decks/studies/complete.html.erb`

**show.html.erb 기존 패턴** (lines 1-9):
```erb
<div class="max-w-2xl mx-auto px-4 py-8">
  <div class="mb-4 text-sm text-gray-500">
    <%= link_to @deck.title, deck_path(@deck), class: "hover:underline" %>
  </div>

  <div id="study-card">
    <%= render "card", card: @due_cards.first, deck: @deck %>
  </div>
</div>
```

**study/show.html.erb 변형:** `@deck` 없으므로 breadcrumb 제거, `#study-card` 구조 동일.

**complete.html.erb 기존 패턴** (lines 1-12):
```erb
<div class="max-w-2xl mx-auto px-4 py-16 text-center">
  <h1 class="text-2xl font-bold text-gray-900 mb-3">오늘의 학습 완료</h1>
  <p class="text-gray-500 mb-8">...</p>
  <%= link_to "덱으로 돌아가기", deck_path(@deck), class: "..." %>
</div>
```

**study/complete.html.erb 변형:** `deck_path(@deck)` → `decks_path` (D-18: `@deck` 없음).

---

### 테스트 파일들 (request specs)

#### `spec/requests/card_reviews_spec.rb`

**Analog:** `spec/requests/cards_spec.rb` (lines 1-46)

**Turbo Stream request spec 패턴**:
```ruby
require "rails_helper"

RSpec.describe "Cards", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  describe "POST /decks/:deck_id/cards" do
    context "인증된 본인 덱에 카드 생성" do
      before { sign_in(user) }

      it "카드를 생성하고 Turbo Stream으로 응답한다" do
        expect {
          post deck_cards_path(deck),
            params: { card: { front: "앞면", back: "뒷면" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }  # Turbo Stream 헤더
        }.to change(Card, :count).by(1)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

**card_reviews_spec.rb 추가 패턴** (`spec/requests/decks/studies_spec.rb` 컨텍스트 구조):
```ruby
context "비인증 사용자" do
  before { delete session_path }   # sign_out 패턴

  it "로그인 페이지로 리다이렉트" do
    post card_reviews_path, params: { ... }
    expect(response).to redirect_to(new_session_path)
  end
end

context "CardReview 카운트 변경 검증 (D-15 analogue)" do
  it "POST는 CardReview를 생성한다" do
    expect { post ... }.to change(CardReview, :count).by(1)
  end
end
```

#### `spec/requests/study_spec.rb`

**Analog:** `spec/requests/decks/studies_spec.rb` (lines 1-63 — 전체 컨텍스트 구조)

컨텍스트 구조 그대로 복사:
- 빈 큐 → 완료 화면 렌더
- due 있음 → 학습 화면 렌더
- 새 카드 있음 → 학습 화면 렌더
- 비인증 → `new_session_path` 리다이렉트

#### `spec/requests/decks/browses_spec.rb`

**Analog:** `spec/requests/decks/studies_spec.rb`

**BROWSE-04 전용 패턴** (codebase에 없는 패턴 — spec으로 강제):
```ruby
describe "GET /decks/:deck_id/browse" do
  it "CardReview를 생성하지 않는다 (BROWSE-04)" do
    expect {
      get deck_browse_path(deck)
    }.not_to change(CardReview, :count)
  end
end
```

---

## Shared Patterns

### 인증 패턴
**Source:** `app/controllers/concerns/authentication.rb` (lines 1-66)
**Apply to:** 모든 컨트롤러
```ruby
# ApplicationController에 include Authentication → 자동 적용
# 추가 before_action :require_authentication 불필요 (A2 확인)
# Current.user = Current.session&.user
```

### Pundit authorize 패턴
**Source:** `app/controllers/cards_controller.rb` (lines 8, 29, 33, 47), `app/controllers/decks/studies_controller.rb` (line 5)
**Apply to:** CardReviewsController, Decks::BrowsesController
```ruby
authorize @resource         # 단일 리소스
authorize @deck, :show?     # 특정 액션 지정
```

### policy_scope 금지 패턴
**Source:** `app/controllers/cards_controller.rb` lines 60-62
```ruby
# policy_scope(Deck) 사용 금지 (scope.none 반환) — 명시적 owner 스코프
@deck = Deck.where(owner: Current.user).find(params[:deck_id])
```
**Apply to:** 모든 컨트롤러의 Deck 스코프 — `policy_scope(Deck)` 절대 금지

### Turbo Stream respond_to 패턴
**Source:** `app/controllers/cards_controller.rb` lines 10-13
**Apply to:** CardReviewsController#create
```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to ..., notice: "..." }
end
```

### 서비스 Result Struct 패턴
**Source:** `app/services/participations/create_service.rb` lines 3-5
**Apply to:** SubmitReviewService
```ruby
Result = Struct.new(:success?, :card_review, :errors, keyword_init: true)
def self.call(**args) = new(**args).call
```

### Query Object join_clause 패턴
**Source:** `app/queries/flashcards/study_queue_query.rb` lines 22-25
**Apply to:** GlobalStudyQueueQuery (동일 메서드 복사)
```ruby
def join_clause
  sanitized_id = ActiveRecord::Base.connection.quote(user.id)
  "LEFT OUTER JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = #{sanitized_id}"
end
```

### Factory traits 패턴
**Source:** `spec/factories/card_reviews.rb` (lines 1-29)
**Apply to:** 모든 card_review 관련 spec
```ruby
create(:card_review, :due, user: user, card: card)    # next_review_at: 1.hour.ago
create(:card_review, :mature, user: user, card: card)  # next_review_at: 5.days.from_now
```

---

## No Analog Found

| 파일 | Role | Data Flow | 이유 |
|---|---|---|---|
| `app/views/decks/studies/_card.html.erb` (확장) | view partial | request-response | front + back + 평가 버튼 + Stimulus 연동 패턴이 기존 코드베이스에 없음. RESEARCH.md Pattern 4 사용. |

---

## Metadata

**Analog 검색 범위:** `app/controllers/`, `app/services/`, `app/queries/`, `app/javascript/controllers/`, `spec/requests/`, `spec/factories/`
**스캔한 파일:** 22개
**Pattern extraction date:** 2026-05-30
