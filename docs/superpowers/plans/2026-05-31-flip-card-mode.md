# Flip Card Mode (주관식 학습) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 주관식 플립 학습 모드 추가 — 카드 앞면 클릭 시 3D 플립으로 뒷면 표시, 3초 후 자동 복귀, 1-5 별점 저장, 난이도 필터 학습 지원.

**Architecture:** 신규 `user_card_ratings` 테이블로 SRS(`card_reviews`)와 별점을 완전 분리. `Decks::FlipsController`가 카드 전체를 JSON으로 내려보내고, `flip_card_controller.js` (Stimulus)가 클라이언트 측 네비게이션·플립·별점을 처리. 별점 저장만 `Decks::CardRatingsController`로 서버 요청.

**Tech Stack:** Rails 8.1, Stimulus (eagerLoadControllersFrom 자동 등록), Turbo, Pundit, RSpec + FactoryBot, CSS 3D transform

---

## File Map

### 신규 생성

| 파일 | 역할 |
|------|------|
| `db/migrate/TIMESTAMP_create_user_card_ratings.rb` | user_card_ratings 테이블 |
| `app/models/user_card_rating.rb` | 별점 모델 (validates difficulty 1–5, unique per user+card) |
| `spec/factories/user_card_ratings.rb` | 팩토리 |
| `spec/models/user_card_rating_spec.rb` | 모델 스펙 |
| `app/controllers/decks/flips_controller.rb` | 플립 학습 페이지 |
| `app/controllers/decks/card_ratings_controller.rb` | 별점 upsert |
| `spec/requests/decks/flips_spec.rb` | 플립 컨트롤러 요청 스펙 |
| `spec/requests/decks/card_ratings_spec.rb` | 별점 컨트롤러 요청 스펙 |
| `app/views/decks/flips/show.html.erb` | 플립 학습 뷰 |
| `app/javascript/controllers/flip_card_controller.js` | Stimulus 플립 컨트롤러 |

### 수정

| 파일 | 변경 내용 |
|------|----------|
| `config/routes.rb` | `flip`, `card_ratings` 라우트 추가 |
| `app/models/card.rb` | `has_many :user_card_ratings` 추가 |
| `app/controllers/decks/studies_controller.rb` | `min_stars` 필터 추가 |
| `app/controllers/decks_controller.rb` | `show`에 `@rated_count` 추가 |
| `app/views/decks/show.html.erb` | 버튼을 드롭다운으로 교체 |
| `app/assets/stylesheets/app.css` | 플립 카드·드롭다운·별점 CSS 추가 |

---

## Task 1: Migration + Model + Factory

**Files:**
- Create: `db/migrate/TIMESTAMP_create_user_card_ratings.rb`
- Create: `app/models/user_card_rating.rb`
- Modify: `app/models/card.rb`
- Create: `spec/factories/user_card_ratings.rb`
- Create: `spec/models/user_card_rating_spec.rb`

- [ ] **Step 1: 스펙 작성**

```ruby
# spec/models/user_card_rating_spec.rb
require "rails_helper"

RSpec.describe UserCardRating, type: :model do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:card) }
  end

  describe "validations" do
    subject { UserCardRating.new(user: user, card: card, difficulty: 3) }

    it { is_expected.to validate_uniqueness_of(:card_id).scoped_to(:user_id) }
    it { is_expected.to validate_numericality_of(:difficulty).only_integer
                                                              .is_greater_than_or_equal_to(1)
                                                              .is_less_than_or_equal_to(5) }
    it { is_expected.to validate_presence_of(:difficulty) }
  end
end
```

- [ ] **Step 2: 스펙 실패 확인**

```bash
bundle exec rspec spec/models/user_card_rating_spec.rb
```

Expected: `NameError: uninitialized constant UserCardRating`

- [ ] **Step 3: 마이그레이션 생성**

```bash
bin/rails g migration CreateUserCardRatings user:references card:references difficulty:integer
```

생성된 마이그레이션 파일을 열어 `null: false` 및 unique index 추가:

```ruby
class CreateUserCardRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :user_card_ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :difficulty, null: false

      t.timestamps
    end

    add_index :user_card_ratings, [:user_id, :card_id], unique: true
  end
end
```

- [ ] **Step 4: 마이그레이션 실행**

```bash
bin/rails db:migrate
```

Expected: `CreateUserCardRatings: migrated`

- [ ] **Step 5: 모델 작성**

```ruby
# app/models/user_card_rating.rb
class UserCardRating < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :difficulty, presence: true,
                         numericality: { only_integer: true, in: 1..5 }
  validates :card_id, uniqueness: { scope: :user_id }
end
```

- [ ] **Step 6: Card 모델에 association 추가**

`app/models/card.rb`의 `belongs_to :deck` 다음 줄에 추가:

```ruby
has_many :user_card_ratings, dependent: :destroy
```

- [ ] **Step 7: 팩토리 작성**

```ruby
# spec/factories/user_card_ratings.rb
FactoryBot.define do
  factory :user_card_rating do
    association :user
    association :card
    difficulty { 3 }
  end
end
```

- [ ] **Step 8: 스펙 통과 확인**

```bash
bundle exec rspec spec/models/user_card_rating_spec.rb
```

Expected: 모든 examples PASS

- [ ] **Step 9: 커밋**

```bash
git add db/migrate/*_create_user_card_ratings.rb \
        db/schema.rb \
        app/models/user_card_rating.rb \
        app/models/card.rb \
        spec/factories/user_card_ratings.rb \
        spec/models/user_card_rating_spec.rb
git commit -m "feat: add UserCardRating model for flip card difficulty ratings"
```

---

## Task 2: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: 라우트 추가**

`config/routes.rb`의 `resources :decks do` 블록에서 기존 라인들 다음에 추가:

```ruby
resources :decks do
  resources :cards, only: %i[create edit update destroy]
  namespace :cards do
    resource :imports, only: %i[new create]
  end
  resource  :study,          only: %i[show], module: :decks
  resource  :browse,         only: %i[show], module: :decks
  resource  :flip,           only: %i[show], module: :decks        # ← 신규
  resources :card_ratings,   only: %i[create], module: :decks      # ← 신규
  resources :study_sessions, only: %i[show], module: :decks
  resource  :fork,           only: %i[create], module: :decks
  resource  :feature,        only: %i[create destroy], module: :decks
end
```

- [ ] **Step 2: 라우트 확인**

```bash
bin/rails routes | grep -E "flip|card_rating"
```

Expected:
```
deck_flip      GET  /decks/:deck_id/flip(.:format)         decks/flips#show
deck_card_ratings POST /decks/:deck_id/card_ratings(.:format) decks/card_ratings#create
```

- [ ] **Step 3: 커밋**

```bash
git add config/routes.rb
git commit -m "feat: add flip and card_ratings routes"
```

---

## Task 3: FlipsController + Spec

**Files:**
- Create: `spec/requests/decks/flips_spec.rb`
- Create: `app/controllers/decks/flips_controller.rb`

- [ ] **Step 1: 요청 스펙 작성**

```ruby
# spec/requests/decks/flips_spec.rb
require "rails_helper"

RSpec.describe "Decks::Flips", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }

  before { sign_in(user) }

  describe "GET /decks/:deck_id/flip" do
    context "카드 없음" do
      it "200 반환" do
        get deck_flip_path(deck)
        expect(response).to have_http_status(:ok)
      end
    end

    context "카드 있음" do
      before { create_list(:card, 3, deck: deck) }

      it "200 반환 및 flip-card 컨트롤러 포함" do
        get deck_flip_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("flip-card")
      end
    end

    context "min_stars 필터" do
      let!(:rated_card)   { create(:card, deck: deck) }
      let!(:unrated_card) { create(:card, deck: deck) }

      before do
        create(:user_card_rating, user: user, card: rated_card, difficulty: 4)
      end

      it "4이상 별점 카드 front를 JSON에 포함" do
        get deck_flip_path(deck, min_stars: 4)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(rated_card.front)
        expect(response.body).not_to include(unrated_card.front)
      end
    end

    context "비인증 사용자" do
      before { delete session_path }  # 로그아웃

      it "로그인 페이지로 리다이렉트" do
        get deck_flip_path(deck)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
```

- [ ] **Step 2: 스펙 실패 확인**

```bash
bundle exec rspec spec/requests/decks/flips_spec.rb
```

Expected: `ActionController::RoutingError` 또는 `NameError: uninitialized constant Decks::FlipsController`

- [ ] **Step 3: 컨트롤러 작성**

```ruby
# app/controllers/decks/flips_controller.rb
class Decks::FlipsController < ApplicationController
  def show
    @deck = Deck.find(params[:deck_id])
    authorize @deck, :show?

    min_stars = params[:min_stars].to_i
    @cards = if min_stars.between?(1, 5)
      @deck.cards
           .joins(:user_card_ratings)
           .where(user_card_ratings: { user: Current.user, difficulty: min_stars.. })
           .order(:position)
    else
      @deck.cards.order(:position)
    end

    @cards_json = @cards.as_json(only: %i[id front back])
    @ratings    = UserCardRating.where(user: Current.user, card: @cards)
                                .pluck(:card_id, :difficulty).to_h
  end
end
```

- [ ] **Step 4: 스펙 통과 확인**

```bash
bundle exec rspec spec/requests/decks/flips_spec.rb
```

Expected: 모든 examples PASS (뷰 없으면 `ActionView::MissingTemplate` — Task 7 완료 후 재실행)

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/decks/flips_controller.rb \
        spec/requests/decks/flips_spec.rb
git commit -m "feat: add Decks::FlipsController with min_stars filter"
```

---

## Task 4: CardRatingsController + Spec

**Files:**
- Create: `spec/requests/decks/card_ratings_spec.rb`
- Create: `app/controllers/decks/card_ratings_controller.rb`

- [ ] **Step 1: 요청 스펙 작성**

```ruby
# spec/requests/decks/card_ratings_spec.rb
require "rails_helper"

RSpec.describe "Decks::CardRatings", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  before { sign_in(user) }

  describe "POST /decks/:deck_id/card_ratings" do
    context "신규 별점 생성" do
      it "200 반환 및 UserCardRating 1개 생성" do
        expect {
          post deck_card_ratings_path(deck),
               params: { card_id: card.id, difficulty: 3 },
               as: :json
        }.to change(UserCardRating, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(3)
      end
    end

    context "기존 별점 업데이트" do
      before { create(:user_card_rating, user: user, card: card, difficulty: 2) }

      it "200 반환 및 레코드 수 변화 없이 업데이트" do
        expect {
          post deck_card_ratings_path(deck),
               params: { card_id: card.id, difficulty: 5 },
               as: :json
        }.not_to change(UserCardRating, :count)
        expect(response).to have_http_status(:ok)
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(5)
      end
    end

    context "범위 초과 difficulty clamp" do
      it "9 → 5로 클램프" do
        post deck_card_ratings_path(deck),
             params: { card_id: card.id, difficulty: 9 },
             as: :json
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(5)
      end

      it "0 → 1로 클램프" do
        post deck_card_ratings_path(deck),
             params: { card_id: card.id, difficulty: 0 },
             as: :json
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(1)
      end
    end

    context "비인증 사용자" do
      before { delete session_path }

      it "로그인 페이지로 리다이렉트" do
        post deck_card_ratings_path(deck), params: { card_id: card.id, difficulty: 3 }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
```

- [ ] **Step 2: 스펙 실패 확인**

```bash
bundle exec rspec spec/requests/decks/card_ratings_spec.rb
```

Expected: `NameError: uninitialized constant Decks::CardRatingsController`

- [ ] **Step 3: 컨트롤러 작성**

```ruby
# app/controllers/decks/card_ratings_controller.rb
class Decks::CardRatingsController < ApplicationController
  before_action :set_deck

  def create
    card = Card.find(params[:card_id])
    authorize @deck, :show?

    rating = UserCardRating.find_or_initialize_by(user: Current.user, card: card)
    rating.update!(difficulty: params[:difficulty].to_i.clamp(1, 5))

    head :ok
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
```

- [ ] **Step 4: 스펙 통과 확인**

```bash
bundle exec rspec spec/requests/decks/card_ratings_spec.rb
```

Expected: 모든 examples PASS

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/decks/card_ratings_controller.rb \
        spec/requests/decks/card_ratings_spec.rb
git commit -m "feat: add Decks::CardRatingsController for difficulty upsert"
```

---

## Task 5: StudiesController min_stars Filter + DecksController @rated_count

**Files:**
- Modify: `app/controllers/decks/studies_controller.rb`
- Modify: `app/controllers/decks_controller.rb`
- Modify: `spec/requests/decks/studies_spec.rb`

- [ ] **Step 1: 기존 studies_spec.rb에 min_stars 테스트 추가**

`spec/requests/decks/studies_spec.rb` 파일의 마지막 `end` 직전에 추가:

```ruby
    context "min_stars 필터" do
      let!(:rated_card)   { create(:card, deck: deck) }
      let!(:unrated_card) { create(:card, deck: deck) }

      before do
        create(:user_card_rating, user: user, card: rated_card, difficulty: 4)
      end

      it "별점 4이상 카드만 학습 대상으로 포함" do
        get deck_study_path(deck, min_stars: 4)
        expect(response).to have_http_status(:ok)
      end

      it "별점 미해당 카드는 학습 대상 제외 (완료 화면 표시)" do
        get deck_study_path(deck, min_stars: 5)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습 완료")
      end
    end
```

- [ ] **Step 2: 스펙 실패 확인**

```bash
bundle exec rspec spec/requests/decks/studies_spec.rb -e "min_stars"
```

Expected: `별점 미해당 카드는 학습 대상 제외` 테스트 FAIL (필터 없으면 완료 화면 안 뜸)

- [ ] **Step 3: StudiesController에 min_stars 필터 추가**

`app/controllers/decks/studies_controller.rb`의 `show` 액션에서 `@due_cards` 할당 이후에 추가:

```ruby
def show
  authorize @deck, :show?

  repeat = params[:repeat].present?

  @due_cards = if repeat
                 @deck.cards
  else
                 Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
  end

  # min_stars 필터 — 별점 등록 카드로 학습 범위 제한
  min_stars = params[:min_stars].to_i
  if min_stars.between?(1, 5)
    rated_ids = UserCardRating.where(user: Current.user, difficulty: min_stars..)
                               .where(card: @deck.cards)
                               .pluck(:card_id)
    @due_cards = @due_cards.where(id: rated_ids)
  end

  if @due_cards.empty?
    render :complete
    return
  end

  StudySession.where(user: Current.user, deck: @deck, completed_at: nil).destroy_all

  @study_session = StudySession.create!(
    user:   Current.user,
    deck:   @deck,
    repeat: repeat
  )

  @current_card    = @due_cards.first
  @total_count     = @deck.cards.count
  @completed_count = 0
  @options         = @current_card.quiz_options(@deck)
end
```

- [ ] **Step 4: DecksController#show에 @rated_count 추가**

`app/controllers/decks_controller.rb`의 `show` 액션:

```ruby
def show
  authorize @deck
  @cards       = @deck.cards.order(:position, :id)
  @rated_count = authenticated? ?
    UserCardRating.where(user: Current.user, card: @cards).count : 0
end
```

- [ ] **Step 5: 스펙 통과 확인**

```bash
bundle exec rspec spec/requests/decks/studies_spec.rb
```

Expected: 모든 examples PASS

- [ ] **Step 6: 커밋**

```bash
git add app/controllers/decks/studies_controller.rb \
        app/controllers/decks_controller.rb \
        spec/requests/decks/studies_spec.rb
git commit -m "feat: add min_stars difficulty filter to study and deck show"
```

---

## Task 6: Flip Card View

**Files:**
- Create: `app/views/decks/flips/show.html.erb`

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p app/views/decks/flips
```

- [ ] **Step 2: 뷰 작성**

```erb
<%# app/views/decks/flips/show.html.erb %>
<% content_for :title, "#{@deck.title} — 주관식 학습" %>

<div class="study-page">
  <header class="study-page__bar">
    <%= link_to deck_path(@deck), class: "study-page__back", aria: { label: "덱으로 돌아가기" } do %>
      <iconify-icon icon="lucide:arrow-left" width="16"></iconify-icon>
      <span class="study-page__back-label"><%= @deck.title %></span>
    <% end %>

    <span class="study-page__mode-chip">
      <iconify-icon icon="lucide:book-open" width="13"></iconify-icon>
      주관식 학습
    </span>
  </header>

  <div class="study-page__body">
    <div class="study-page__card-wrap">
      <% if @cards.any? %>
        <div data-controller="flip-card"
             data-flip-card-cards-value="<%= @cards_json.to_json %>"
             data-flip-card-ratings-value="<%= @ratings.to_json %>"
             data-flip-card-deck-id-value="<%= @deck.id %>">

          <%# 별점 %>
          <div class="flip-rating" aria-label="난이도 별점">
            <span class="flip-rating__label">난이도</span>
            <% 5.times do |i| %>
              <button type="button"
                      class="flip-star"
                      data-flip-card-target="star"
                      data-action="click->flip-card#rate"
                      data-star="<%= i + 1 %>"
                      aria-label="별 <%= i + 1 %>개">★</button>
            <% end %>
          </div>

          <%# 플립 카드 %>
          <div class="flip-card"
               data-action="click->flip-card#flip"
               role="button"
               tabindex="0"
               aria-label="카드 뒤집기">
            <div class="flip-card__inner" data-flip-card-target="inner">
              <div class="flip-card__front">
                <p class="flip-card__text" data-flip-card-target="front"></p>
                <p class="flip-card__hint">클릭해서 정답 확인</p>
              </div>
              <div class="flip-card__back">
                <p class="flip-card__text" data-flip-card-target="back"></p>
                <div class="flip-countdown hidden" data-flip-card-target="countdown"></div>
              </div>
            </div>
          </div>

          <%# 네비게이션 %>
          <div class="flip-nav">
            <button type="button"
                    class="flip-nav__btn"
                    data-flip-card-target="prevBtn"
                    data-action="click->flip-card#navigate"
                    data-direction="prev"
                    aria-label="이전 카드">
              <iconify-icon icon="lucide:arrow-left" width="14"></iconify-icon>
              이전
            </button>
            <span class="flip-nav__counter" data-flip-card-target="counter">
              1 / <%= @cards.size %>
            </span>
            <button type="button"
                    class="flip-nav__btn"
                    data-flip-card-target="nextBtn"
                    data-action="click->flip-card#navigate"
                    data-direction="next"
                    aria-label="다음 카드">
              다음
              <iconify-icon icon="lucide:arrow-right" width="14"></iconify-icon>
            </button>
          </div>

          <p class="flip-hint-text">
            키보드 <kbd>Space</kbd> 뒤집기 &middot; <kbd>←</kbd><kbd>→</kbd> 이동 &middot; <kbd>1</kbd>–<kbd>5</kbd> 별점
          </p>
        </div>
      <% else %>
        <div class="flip-empty">
          <p>해당 조건의 카드가 없습니다.</p>
          <%= link_to "전체 카드로 학습하기", deck_flip_path(@deck), class: "btn btn--primary btn--sm" %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: 스펙 통과 확인 (Task 3 스펙 재실행)**

```bash
bundle exec rspec spec/requests/decks/flips_spec.rb
```

Expected: 모든 examples PASS

- [ ] **Step 4: 커밋**

```bash
git add app/views/decks/flips/show.html.erb
git commit -m "feat: add flip card view"
```

---

## Task 7: Stimulus flip_card_controller.js

**Files:**
- Create: `app/javascript/controllers/flip_card_controller.js`

- [ ] **Step 1: 컨트롤러 작성**

```javascript
// app/javascript/controllers/flip_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { cards: Array, ratings: Object, deckId: Number }
  static targets = ["front", "back", "inner", "counter",
                    "prevBtn", "nextBtn", "star", "countdown"]

  connect() {
    this.index         = 0
    this.flipped       = false
    this.countdownTimer = null
    this.handleKeydown  = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this.render()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    this.clearTimers()
  }

  // ── Flip ────────────────────────────────────────────────────────
  flip() {
    if (!this.flipped) {
      this.flipped = true
      this.innerTarget.classList.add("flip-card__inner--flipped")
      this.startCountdown()
    } else {
      this.flipped = false
      this.innerTarget.classList.remove("flip-card__inner--flipped")
      this.clearTimers()
      this.countdownTarget.classList.add("hidden")
    }
  }

  startCountdown() {
    let remaining = 3
    this.countdownTarget.textContent = remaining
    this.countdownTarget.classList.remove("hidden")
    this.countdownTimer = setInterval(() => {
      remaining -= 1
      if (remaining > 0) {
        this.countdownTarget.textContent = remaining
      } else {
        this.clearTimers()
        this.flip()
      }
    }, 1000)
  }

  clearTimers() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer)
      this.countdownTimer = null
    }
  }

  // ── Navigation ──────────────────────────────────────────────────
  navigate(event) {
    const dir = event.currentTarget.dataset.direction
    this.clearTimers()
    if (this.flipped) {
      this.flipped = false
      this.innerTarget.classList.remove("flip-card__inner--flipped")
      this.countdownTarget.classList.add("hidden")
    }
    if (dir === "prev") {
      this.index = Math.max(0, this.index - 1)
    } else {
      this.index = Math.min(this.cardsValue.length - 1, this.index + 1)
    }
    this.render()
  }

  // ── Star rating ─────────────────────────────────────────────────
  rate(event) {
    const stars = parseInt(event.currentTarget.dataset.star, 10)
    const card  = this.cardsValue[this.index]

    // Optimistic UI update
    this.ratingsValue = { ...this.ratingsValue, [String(card.id)]: stars }
    this.renderStars()

    // Persist to server
    const csrf = document.querySelector('meta[name="csrf-token"]').content
    fetch(`/decks/${this.deckIdValue}/card_ratings`, {
      method:  "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
      body:    JSON.stringify({ card_id: card.id, difficulty: stars })
    })
  }

  // ── Keyboard ────────────────────────────────────────────────────
  handleKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    switch (event.key) {
      case " ":
      case "Enter":
        event.preventDefault()
        this.flip()
        break
      case "ArrowLeft":
        event.preventDefault()
        if (!this.prevBtnTarget.disabled) this.prevBtnTarget.click()
        break
      case "ArrowRight":
        event.preventDefault()
        if (!this.nextBtnTarget.disabled) this.nextBtnTarget.click()
        break
      default: {
        const n = parseInt(event.key, 10)
        if (n >= 1 && n <= 5) {
          event.preventDefault()
          this.starTargets[n - 1]?.click()
        }
      }
    }
  }

  // ── Render ──────────────────────────────────────────────────────
  render() {
    const card = this.cardsValue[this.index]
    this.frontTarget.textContent    = card.front
    this.backTarget.textContent     = card.back
    this.counterTarget.textContent  = `${this.index + 1} / ${this.cardsValue.length}`
    this.prevBtnTarget.disabled     = this.index === 0
    this.nextBtnTarget.disabled     = this.index === this.cardsValue.length - 1
    this.renderStars()
  }

  renderStars() {
    const card   = this.cardsValue[this.index]
    const rating = this.ratingsValue[String(card.id)] || 0
    this.starTargets.forEach((star, i) => {
      star.classList.toggle("flip-star--active", i < rating)
    })
  }
}
```

- [ ] **Step 2: 커밋**

```bash
git add app/javascript/controllers/flip_card_controller.js
git commit -m "feat: add flip_card Stimulus controller with flip, nav, and star rating"
```

---

## Task 8: CSS 추가

**Files:**
- Modify: `app/assets/stylesheets/app.css`

- [ ] **Step 1: app.css 마지막에 스타일 추가**

`app/assets/stylesheets/app.css` 파일의 맨 끝에 추가:

```css
/* ═══════════════════════════════════════════════════════════════
   Flip Card Mode (주관식 학습)
   ═══════════════════════════════════════════════════════════════ */

/* ── Study mode dropdown ──────────────────────────────────────── */
.study-dropdown {
  position: relative;
  display: inline-block;
}
.study-dropdown summary {
  list-style: none;
  cursor: pointer;
}
.study-dropdown summary::-webkit-details-marker { display: none; }
.study-dropdown__menu {
  display: none;
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  background: #ffffff;
  border: 1px solid #e4e4e7;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  min-width: 160px;
  z-index: 50;
  padding: 4px;
}
.study-dropdown[open] .study-dropdown__menu { display: block; }
.study-dropdown__item {
  display: block;
  padding: 8px 12px;
  font-size: 13px;
  color: #374151;
  text-decoration: none;
  border-radius: 6px;
  white-space: nowrap;
}
.study-dropdown__item:hover { background: #f4f4f5; color: #09090b; }
.study-dropdown__divider { border-top: 1px solid #e4e4e7; margin: 4px 0; }

/* ── Flip card 3D ─────────────────────────────────────────────── */
.flip-card {
  perspective: 1000px;
  cursor: pointer;
  margin-bottom: 24px;
  border-radius: 16px;
  user-select: none;
}
.flip-card__inner {
  position: relative;
  min-height: 220px;
  transition: transform 0.45s ease;
  transform-style: preserve-3d;
  border-radius: 16px;
}
.flip-card__inner--flipped { transform: rotateY(180deg); }
.flip-card__front,
.flip-card__back {
  position: absolute;
  inset: 0;
  backface-visibility: hidden;
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px;
  background: #ffffff;
  border: 1px solid #e4e4e7;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
}
.flip-card__back {
  transform: rotateY(180deg);
  background: #f7fee7;
  border-color: #d9f99d;
}
.flip-card__text {
  font-size: 1.2rem;
  font-weight: 600;
  color: #09090b;
  text-align: center;
  line-height: 1.55;
  margin: 0;
}
.flip-card__hint {
  font-size: 0.8rem;
  color: #a1a1aa;
  margin-top: 14px;
  text-align: center;
}

/* ── Countdown ────────────────────────────────────────────────── */
.flip-countdown {
  position: absolute;
  bottom: 12px;
  right: 16px;
  font-size: 22px;
  font-weight: 700;
  color: #65a30d;
  opacity: 0.75;
  line-height: 1;
}
.hidden { display: none !important; }

/* ── Star rating ──────────────────────────────────────────────── */
.flip-rating {
  display: flex;
  align-items: center;
  gap: 2px;
  margin-bottom: 14px;
}
.flip-rating__label {
  font-size: 12px;
  color: #71717a;
  margin-right: 6px;
  font-weight: 500;
}
.flip-star {
  background: none;
  border: none;
  font-size: 24px;
  color: #d4d4d8;
  cursor: pointer;
  padding: 2px 1px;
  line-height: 1;
  transition: color 0.1s, transform 0.1s;
}
.flip-star:hover,
.flip-star--active { color: #f59e0b; }
.flip-star:hover { transform: scale(1.15); }

/* ── Navigation ───────────────────────────────────────────────── */
.flip-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}
.flip-nav__btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 10px 20px;
  min-height: 44px;
  border: 1px solid #e4e4e7;
  border-radius: 8px;
  background: #ffffff;
  color: #374151;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s;
}
.flip-nav__btn:hover:not(:disabled) { background: #f4f4f5; border-color: #d4d4d8; }
.flip-nav__btn:disabled { opacity: 0.4; cursor: not-allowed; }
.flip-nav__counter {
  flex: 1;
  text-align: center;
  font-size: 14px;
  font-weight: 500;
  color: #71717a;
}

/* ── Keyboard hint ────────────────────────────────────────────── */
.flip-hint-text {
  margin-top: 18px;
  text-align: center;
  font-size: 12px;
  color: #a1a1aa;
}
.flip-hint-text kbd {
  display: inline-block;
  padding: 1px 5px;
  border: 1px solid #d4d4d8;
  border-radius: 4px;
  font-size: 11px;
  background: #f4f4f5;
}

/* ── Empty state ──────────────────────────────────────────────── */
.flip-empty {
  text-align: center;
  padding: 64px 24px;
  color: #71717a;
}
.flip-empty p { margin-bottom: 16px; font-size: 15px; }
```

- [ ] **Step 2: 커밋**

```bash
git add app/assets/stylesheets/app.css
git commit -m "feat: add flip card, dropdown, and star rating CSS"
```

---

## Task 9: 덱 Show 페이지 버튼 드롭다운으로 교체

**Files:**
- Modify: `app/views/decks/show.html.erb`

- [ ] **Step 1: 버튼 영역 교체**

`app/views/decks/show.html.erb`에서 아래 기존 코드:

```erb
          <% if @deck.cards.size.positive? %>
              <%= link_to "학습 시작", deck_study_path(@deck), class: "btn btn--primary btn--sm" %>
              <%= link_to "훑어보기", deck_browse_path(@deck), class: "btn btn--ghost btn--sm" %>
            <% else %>
              <button type="button" class="btn btn--primary btn--sm" disabled aria-disabled="true" title="카드를 먼저 추가하세요">학습 시작</button>
              <span style="font-size:0.85rem; color:#6b7280; align-self:center;">카드를 먼저 추가하세요</span>
```

를 아래로 교체:

```erb
          <% if @deck.cards.size.positive? %>
              <details class="study-dropdown">
                <summary class="btn btn--primary btn--sm">학습 시작</summary>
                <div class="study-dropdown__menu">
                  <%= link_to "전체 카드", deck_study_path(@deck), class: "study-dropdown__item" %>
                  <% if authenticated? && @rated_count > 0 %>
                    <div class="study-dropdown__divider"></div>
                    <% (1..5).each do |n| %>
                      <%= link_to "#{"★" * n}#{"☆" * (5 - n)} 이상",
                            deck_study_path(@deck, min_stars: n),
                            class: "study-dropdown__item" %>
                    <% end %>
                  <% end %>
                </div>
              </details>

              <details class="study-dropdown">
                <summary class="btn btn--ghost btn--sm">주관식 학습</summary>
                <div class="study-dropdown__menu">
                  <%= link_to "전체 카드", deck_flip_path(@deck), class: "study-dropdown__item" %>
                  <% if authenticated? && @rated_count > 0 %>
                    <div class="study-dropdown__divider"></div>
                    <% (1..5).each do |n| %>
                      <%= link_to "#{"★" * n}#{"☆" * (5 - n)} 이상",
                            deck_flip_path(@deck, min_stars: n),
                            class: "study-dropdown__item" %>
                    <% end %>
                  <% end %>
                </div>
              </details>

              <%= link_to "훑어보기", deck_browse_path(@deck), class: "btn btn--ghost btn--sm" %>
            <% else %>
              <button type="button" class="btn btn--primary btn--sm" disabled aria-disabled="true" title="카드를 먼저 추가하세요">학습 시작</button>
              <span style="font-size:0.85rem; color:#6b7280; align-self:center;">카드를 먼저 추가하세요</span>
```

- [ ] **Step 2: 전체 스펙 실행**

```bash
bundle exec rspec
```

Expected: 모든 examples PASS (또는 기존 실패만 남음)

- [ ] **Step 3: 커밋**

```bash
git add app/views/decks/show.html.erb
git commit -m "feat: replace deck show buttons with study/flip dropdown menus"
```

---

## Task 10: 브라우저 검증

- [ ] **Step 1: 도커 컨테이너에 반영**

```bash
docker compose -f docker-compose.dev.yml build
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
```

- [ ] **Step 2: 주관식 학습 golden path 확인**

1. `http://localhost:3000/decks` 접속 → 주식투자 공식 덱 클릭
2. "주관식 학습" 드롭다운 → "전체 카드" 클릭
3. 카드 앞면 표시 확인
4. 카드 클릭 → 3D 플립 → 뒷면 + 카운트다운 표시 확인
5. 3초 후 자동 복귀 확인
6. 별점 클릭 → 하이라이트 즉시 반영 확인
7. 페이지 새로고침 후 별점 유지 확인
8. 키보드 `Space`, `←`, `→`, `3` 동작 확인

- [ ] **Step 3: 난이도 필터 확인**

1. 몇 장에 별점 등록
2. 덱 show 페이지로 돌아와 드롭다운 확인 (★이상 메뉴 노출 여부)
3. "★★★이상" 선택 → 해당 카드만 로드 확인

- [ ] **Step 4: 최종 커밋 및 푸시**

```bash
git push origin main
```

---

## Self-Review Checklist

- [x] **Spec coverage**: 모든 섹션에 대응 Task 존재
  - Data model → Task 1
  - Routes → Task 2
  - FlipsController (min_stars 포함) → Task 3
  - CardRatingsController (upsert, clamp) → Task 4
  - StudiesController min_stars → Task 5
  - Flip view (empty state 포함) → Task 6
  - Stimulus controller (flip, nav, rating, keyboard) → Task 7
  - CSS (dropdown, flip, stars, nav) → Task 8
  - Deck show dropdown → Task 9
  - Browser verification → Task 10

- [x] **Placeholder scan**: TBD/TODO 없음

- [x] **Type consistency**:
  - `ratingsValue[String(card.id)]` — Ruby `.to_h`는 Integer key를 JSON 직렬화 시 문자열로, JS에서 일관되게 `String(card.id)` 사용
  - `data-direction="prev"/"next"` — navigate() 메서드와 일치
  - `data-star` — rate() 메서드의 `event.currentTarget.dataset.star`와 일치
  - `flip-card__inner--flipped` — CSS 클래스명과 JS 일치
  - `deck_flip_path` — singular resource (routes: `resource :flip`) 경로명과 일치
  - `deck_card_ratings_path` — plural resource (routes: `resources :card_ratings`) 경로명과 일치
