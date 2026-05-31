# Study Session Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-user study session tracking to flashcard decks — showing study count + last score on deck cards, enabling repeat study, and displaying a per-card correct/incorrect results page after each session.

**Architecture:** Introduce two new models (`StudySession`, `StudySessionAnswer`) to record each study attempt. `Decks::StudiesController` creates a session on study start; `CardReviewsController` appends answers and redirects to a results page on completion. The deck hub page preloads per-deck stats via a query object.

**Tech Stack:** Rails 8, SQLite, Hotwire Turbo, RSpec + FactoryBot, Pundit, Tailwind CSS

---

## File Map

| Action | Path |
|--------|------|
| Create | `db/migrate/..._create_study_sessions.rb` |
| Create | `db/migrate/..._create_study_session_answers.rb` |
| Create | `app/models/study_session.rb` |
| Create | `app/models/study_session_answer.rb` |
| Create | `spec/factories/study_sessions.rb` |
| Create | `spec/factories/study_session_answers.rb` |
| Create | `spec/models/study_session_spec.rb` |
| Create | `app/policies/study_session_policy.rb` |
| Create | `app/queries/flashcards/deck_session_stats_query.rb` |
| Create | `app/controllers/decks/study_sessions_controller.rb` |
| Create | `app/views/decks/study_sessions/show.html.erb` |
| Modify | `config/routes.rb` |
| Modify | `app/controllers/decks/studies_controller.rb` |
| Modify | `app/controllers/decks_controller.rb` |
| Modify | `app/controllers/card_reviews_controller.rb` |
| Modify | `app/views/card_reviews/create.turbo_stream.erb` |
| Modify | `app/views/decks/studies/show.html.erb` |
| Modify | `app/views/decks/studies/_card.html.erb` |
| Modify | `app/views/decks/studies/_complete.html.erb` |
| Modify | `app/views/decks/_deck.html.erb` |
| Modify | `app/assets/stylesheets/app.css` |

---

### Task 1: Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_create_study_sessions.rb`
- Create: `db/migrate/TIMESTAMP_create_study_session_answers.rb`

- [ ] **Step 1: Generate study_sessions migration**

```bash
bin/rails g migration CreateStudySessions user:references deck:references repeat:boolean completed_at:datetime total_count:integer correct_count:integer
```

Expected: creates `db/migrate/TIMESTAMP_create_study_sessions.rb`

- [ ] **Step 2: Edit the study_sessions migration to add defaults and indexes**

Open the generated file and replace its content:

```ruby
class CreateStudySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :study_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :deck, null: false, foreign_key: true
      t.boolean  :repeat,        null: false, default: false
      t.datetime :completed_at
      t.integer  :total_count,   null: false, default: 0
      t.integer  :correct_count, null: false, default: 0
      t.timestamps
    end

    add_index :study_sessions, %i[user_id deck_id]
    add_index :study_sessions, %i[user_id completed_at]
  end
end
```

- [ ] **Step 3: Generate study_session_answers migration**

```bash
bin/rails g migration CreateStudySessionAnswers study_session:references card:references rating:integer is_correct:boolean
```

- [ ] **Step 4: Edit study_session_answers migration**

```ruby
class CreateStudySessionAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :study_session_answers do |t|
      t.references :study_session, null: false, foreign_key: true
      t.references :card,          null: false, foreign_key: true
      t.integer  :rating,     null: false
      t.boolean  :is_correct, null: false
      t.timestamps
    end

    add_index :study_session_answers, %i[study_session_id card_id], unique: true
  end
end
```

- [ ] **Step 5: Run migrations**

```bash
bin/rails db:migrate
```

Expected output ends with: `== CreateStudySessionAnswers: migrated`

- [ ] **Step 6: Verify schema**

```bash
bin/rails db:migrate:status
```

Expected: both migrations show `up`.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add study_sessions and study_session_answers tables"
```

---

### Task 2: Models + Factories

**Files:**
- Create: `app/models/study_session.rb`
- Create: `app/models/study_session_answer.rb`
- Create: `spec/factories/study_sessions.rb`
- Create: `spec/factories/study_session_answers.rb`

- [ ] **Step 1: Write failing model spec**

Create `spec/models/study_session_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe StudySession, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:deck) }
    it { should have_many(:study_session_answers).dependent(:destroy) }
  end

  describe '.completed' do
    it 'includes sessions with completed_at set' do
      done    = create(:study_session, completed_at: 1.hour.ago, total_count: 5, correct_count: 4)
      pending = create(:study_session, completed_at: nil)
      expect(StudySession.completed).to include(done)
      expect(StudySession.completed).not_to include(pending)
    end
  end

  describe '#score_pct' do
    it 'returns nil when total_count is zero' do
      s = build(:study_session, total_count: 0, correct_count: 0)
      expect(s.score_pct).to be_nil
    end

    it 'returns rounded integer percentage' do
      s = build(:study_session, total_count: 10, correct_count: 8)
      expect(s.score_pct).to eq(80)
    end

    it 'rounds down correctly' do
      s = build(:study_session, total_count: 3, correct_count: 1)
      expect(s.score_pct).to eq(33)
    end
  end

  describe '#complete!' do
    it 'sets completed_at, total_count, correct_count' do
      session = create(:study_session)
      freeze_time do
        session.complete!(total: 10, correct: 7)
        expect(session.completed_at).to eq(Time.current)
        expect(session.total_count).to eq(10)
        expect(session.correct_count).to eq(7)
      end
    end
  end
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/models/study_session_spec.rb
```

Expected: fails with `uninitialized constant StudySession` or `NameError`.

- [ ] **Step 3: Create StudySession model**

Create `app/models/study_session.rb`:

```ruby
class StudySession < ApplicationRecord
  belongs_to :user
  belongs_to :deck
  has_many :study_session_answers, dependent: :destroy

  scope :completed, -> { where.not(completed_at: nil) }

  def complete!(total:, correct:)
    update!(completed_at: Time.current, total_count: total, correct_count: correct)
  end

  def score_pct
    return nil if total_count.zero?
    (correct_count.to_f / total_count * 100).round
  end
end
```

- [ ] **Step 4: Create StudySessionAnswer model**

Create `app/models/study_session_answer.rb`:

```ruby
class StudySessionAnswer < ApplicationRecord
  belongs_to :study_session
  belongs_to :card

  validates :card_id, uniqueness: { scope: :study_session_id }
end
```

- [ ] **Step 5: Create factories**

Create `spec/factories/study_sessions.rb`:

```ruby
FactoryBot.define do
  factory :study_session do
    association :user
    association :deck
    repeat        { false }
    completed_at  { nil }
    total_count   { 0 }
    correct_count { 0 }

    trait :completed do
      completed_at  { 1.hour.ago }
      total_count   { 10 }
      correct_count { 8 }
    end
  end
end
```

Create `spec/factories/study_session_answers.rb`:

```ruby
FactoryBot.define do
  factory :study_session_answer do
    association :study_session
    association :card
    rating     { 4 }
    is_correct { true }

    trait :incorrect do
      rating     { 1 }
      is_correct { false }
    end
  end
end
```

- [ ] **Step 6: Run spec — confirm green**

```bash
bundle exec rspec spec/models/study_session_spec.rb
```

Expected: all examples pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/study_session.rb app/models/study_session_answer.rb \
        spec/factories/study_sessions.rb spec/factories/study_session_answers.rb \
        spec/models/study_session_spec.rb
git commit -m "feat: add StudySession and StudySessionAnswer models with specs"
```

---

### Task 3: Routes + Policy

**Files:**
- Modify: `config/routes.rb`
- Create: `app/policies/study_session_policy.rb`

- [ ] **Step 1: Add study_sessions resource to routes**

In `config/routes.rb`, find the decks resources block and add the new nested resource:

```ruby
resources :decks do
  resource  :study,          only: %i[show], module: :decks
  resource  :browse,         only: %i[show], module: :decks
  resources :study_sessions, only: %i[show], module: :decks   # ADD THIS LINE
end
```

- [ ] **Step 2: Verify routes**

```bash
bin/rails routes | grep study_session
```

Expected output includes:
```
deck_study_session  GET  /decks/:deck_id/study_sessions/:id(.:format)  decks/study_sessions#show
```

- [ ] **Step 3: Create StudySessionPolicy**

Create `app/policies/study_session_policy.rb`:

```ruby
class StudySessionPolicy < ApplicationPolicy
  def show?
    record.user == user
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/policies/study_session_policy.rb
git commit -m "feat: add study_sessions route and Pundit policy"
```

---

### Task 4: DeckSessionStatsQuery

**Files:**
- Create: `app/queries/flashcards/deck_session_stats_query.rb`

- [ ] **Step 1: Create the query object**

Create `app/queries/flashcards/deck_session_stats_query.rb`:

```ruby
module Flashcards
  class DeckSessionStatsQuery
    Result = Struct.new(:session_count, :last_score_pct, keyword_init: true)

    def initialize(user:, deck_ids:)
      @user     = user
      @deck_ids = Array(deck_ids)
    end

    def call
      return {} if @deck_ids.empty?

      counts = StudySession.completed
                           .where(user: @user, deck_id: @deck_ids)
                           .group(:deck_id)
                           .count

      last_ids = StudySession.completed
                             .where(user: @user, deck_id: @deck_ids)
                             .group(:deck_id)
                             .maximum(:id)

      last_sessions = last_ids.any? ?
        StudySession.where(id: last_ids.values).index_by(&:deck_id) : {}

      @deck_ids.each_with_object({}) do |deck_id, hash|
        last = last_sessions[deck_id]
        hash[deck_id] = Result.new(
          session_count:  counts[deck_id] || 0,
          last_score_pct: last&.score_pct
        )
      end
    end
  end
end
```

- [ ] **Step 2: Smoke-test in console**

```bash
bin/rails runner "puts Flashcards::DeckSessionStatsQuery.new(user: User.first, deck_ids: Deck.limit(3).pluck(:id)).call.inspect"
```

Expected: prints a hash (empty or with Result structs, no errors).

- [ ] **Step 3: Commit**

```bash
git add app/queries/flashcards/deck_session_stats_query.rb
git commit -m "feat: add DeckSessionStatsQuery for per-deck study stats"
```

---

### Task 5: Update Decks::StudiesController

**Files:**
- Modify: `app/controllers/decks/studies_controller.rb`

- [ ] **Step 1: Replace show action**

Open `app/controllers/decks/studies_controller.rb`. Replace the entire file:

```ruby
class Decks::StudiesController < ApplicationController
  before_action :set_deck

  def show
    authorize @deck, :show?

    repeat = params[:repeat].present?

    @due_cards = if repeat
                   @deck.cards
                 else
                   Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
                 end

    if @due_cards.empty?
      render :complete
      return
    end

    # Discard any abandoned in-progress session for this user+deck
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

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
```

- [ ] **Step 2: Update studies/show.html.erb to pass study_session**

Open `app/views/decks/studies/show.html.erb`. Find the render call for the card partial and add `study_session: @study_session`:

```erb
<%= render "card", card: @current_card, deck: @deck,
    options: @options, completed_count: @completed_count, total_count: @total_count,
    study_session: @study_session %>
```

- [ ] **Step 3: Verify server starts**

```bash
bin/rails runner "puts 'ok'"
```

Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add app/controllers/decks/studies_controller.rb app/views/decks/studies/show.html.erb
git commit -m "feat: StudiesController creates StudySession on study start"
```

---

### Task 6: Update CardReviewsController

**Files:**
- Modify: `app/controllers/card_reviews_controller.rb`
- Modify: `app/views/card_reviews/create.turbo_stream.erb`

- [ ] **Step 1: Replace card_reviews_controller.rb**

```ruby
# frozen_string_literal: true

class CardReviewsController < ApplicationController
  def create
    @card = Card.find(params[:card_review][:card_id])
    @card_review = CardReview.new(user: Current.user, card: @card)
    authorize @card_review

    @deck = @card.deck
    authorize @deck, :show?

    rating = params[:card_review][:rating].to_i

    @study_session = StudySession.find_by(
      id:   params[:card_review][:study_session_id],
      user: Current.user
    )

    begin
      result = Flashcards::SubmitReviewService.call(
        user:    Current.user,
        card_id: @card.id,
        rating:  rating
      )
    rescue ArgumentError
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("study-card", partial: "card_reviews/error"),
                 status: :unprocessable_entity
        end
        format.html { redirect_back_or_to(root_path, alert: "잘못된 평가입니다.") }
      end
      return
    end

    unless result.success?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("study-card", partial: "card_reviews/error"),
                 status: :unprocessable_entity
        end
        format.html { redirect_back_or_to(root_path, alert: result.errors.join(", ")) }
      end
      return
    end

    # Record answer in session
    if @study_session
      StudySessionAnswer.create!(
        study_session: @study_session,
        card:          @card,
        rating:        rating,
        is_correct:    rating >= 3
      )
    end

    # Compute remaining cards for this session
    due_remaining = if @study_session&.repeat?
                      answered_ids = @study_session.study_session_answers.pluck(:card_id)
                      @deck.cards.where.not(id: answered_ids)
                    else
                      Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
                    end

    @next_card = due_remaining.first

    if @next_card.nil?
      # All cards answered — complete session and navigate to results
      if @study_session
        total   = @study_session.study_session_answers.count
        correct = @study_session.study_session_answers.where(is_correct: true).count
        @study_session.complete!(total: total, correct: correct)
        redirect_to deck_study_session_path(@deck, @study_session), status: :see_other
      else
        redirect_to deck_path(@deck), status: :see_other
      end
      return
    end

    @options         = @next_card.quiz_options(@deck)
    @total_count     = @deck.cards.count
    @completed_count = @study_session ? @study_session.study_session_answers.count : 0

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(root_path) }
    end
  end
end
```

- [ ] **Step 2: Update create.turbo_stream.erb**

Replace `app/views/card_reviews/create.turbo_stream.erb` with:

```erb
<%= turbo_stream.update "study-card" do %>
  <%= render "decks/studies/card", card: @next_card, deck: @deck,
      options: @options, completed_count: @completed_count, total_count: @total_count,
      study_session: @study_session %>
<% end %>
```

- [ ] **Step 3: Add study_session_id hidden field to card partial**

Open `app/views/decks/studies/_card.html.erb`. Find the form and add the hidden field inside `form_with`:

```erb
<%= form_with url: card_reviews_path, method: :post,
    data: { turbo: true, "quiz-session-target": "form" } do |f| %>
  <%= f.hidden_field "card_review[card_id]",          value: card.id %>
  <%= f.hidden_field "card_review[deck_id]",          value: deck.id %>
  <%= f.hidden_field "card_review[study_session_id]", value: local_assigns[:study_session]&.id %>
  <%= f.hidden_field "card_review[rating]", value: "",
      data: { "quiz-session-target": "rating" } %>
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/card_reviews_controller.rb \
        app/views/card_reviews/create.turbo_stream.erb \
        app/views/decks/studies/_card.html.erb
git commit -m "feat: CardReviewsController tracks session answers, redirects to results on completion"
```

---

### Task 7: StudySessionsController + Results View

**Files:**
- Create: `app/controllers/decks/study_sessions_controller.rb`
- Create: `app/views/decks/study_sessions/show.html.erb`

- [ ] **Step 1: Create the controller**

Create `app/controllers/decks/study_sessions_controller.rb`:

```ruby
class Decks::StudySessionsController < ApplicationController
  before_action :set_deck
  before_action :set_session

  def show
    authorize @study_session
    @correct_answers   = @study_session.study_session_answers
                                       .where(is_correct: true)
                                       .includes(:card)
                                       .order(:created_at)
    @incorrect_answers = @study_session.study_session_answers
                                       .where(is_correct: false)
                                       .includes(:card)
                                       .order(:created_at)
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def set_session
    @study_session = StudySession.find(params[:id])
  end
end
```

- [ ] **Step 2: Create the results view**

Create directory `app/views/decks/study_sessions/` and file `show.html.erb`:

```erb
<% content_for :title, "학습 결과 — #{@deck.title}" %>

<div class="cl-page">
  <div class="study-results">

    <%# ── Score header ───────────────────────────────────── %>
    <div class="study-results__header">
      <p class="study-results__emoji">🎉</p>
      <h1 class="study-results__title">학습 완료</h1>
      <p class="study-results__score">
        <%= @study_session.correct_count %> / <%= @study_session.total_count %> 정답
        <% if @study_session.score_pct %>
          <span class="study-results__pct">(<%= @study_session.score_pct %>%)</span>
        <% end %>
      </p>
    </div>

    <%# ── Correct cards ───────────────────────────────────── %>
    <% if @correct_answers.any? %>
    <section class="study-results__section">
      <h2 class="study-results__section-title study-results__section-title--correct">
        ✅ 맞춘 카드 (<%= @correct_answers.size %>)
      </h2>
      <div class="study-results__list">
        <% @correct_answers.each do |answer| %>
          <div class="study-results__item study-results__item--correct">
            <span class="study-results__item-front"><%= answer.card.front %></span>
            <span class="study-results__item-sep">—</span>
            <span class="study-results__item-back"><%= answer.card.back %></span>
          </div>
        <% end %>
      </div>
    </section>
    <% end %>

    <%# ── Incorrect cards ─────────────────────────────────── %>
    <% if @incorrect_answers.any? %>
    <section class="study-results__section">
      <h2 class="study-results__section-title study-results__section-title--incorrect">
        ❌ 틀린 카드 (<%= @incorrect_answers.size %>)
      </h2>
      <div class="study-results__list">
        <% @incorrect_answers.each do |answer| %>
          <div class="study-results__item study-results__item--incorrect">
            <span class="study-results__item-front"><%= answer.card.front %></span>
            <span class="study-results__item-sep">—</span>
            <span class="study-results__item-back"><%= answer.card.back %></span>
          </div>
        <% end %>
      </div>
    </section>
    <% end %>

    <%# ── Actions ─────────────────────────────────────────── %>
    <div class="study-results__actions">
      <%= link_to deck_path(@deck), class: "btn btn--secondary" do %>
        <iconify-icon icon="lucide:arrow-left" width="13"></iconify-icon>
        덱으로 돌아가기
      <% end %>
      <%= link_to deck_study_path(@deck, repeat: true), class: "btn btn--primary" do %>
        <iconify-icon icon="lucide:refresh-cw" width="13"></iconify-icon>
        다시 학습하기
      <% end %>
    </div>

  </div>
</div>
```

- [ ] **Step 3: Add CSS for study-results component**

Open `app/assets/stylesheets/app.css`. Append at the end:

```css
/* study-results component */
.study-results { max-width:640px; margin:0 auto; padding:32px 16px 48px; }
.study-results__header { text-align:center; margin-bottom:32px; }
.study-results__emoji  { font-size:3rem; margin:0 0 8px; }
.study-results__title  { font-size:1.5rem; font-weight:700; color:#111; margin:0 0 8px; }
.study-results__score  { font-size:1.1rem; color:#374151; margin:0; }
.study-results__pct    { color:#6b7280; }
.study-results__section { margin-bottom:28px; }
.study-results__section-title { font-size:1rem; font-weight:600; margin:0 0 12px; }
.study-results__section-title--correct   { color:#15803d; }
.study-results__section-title--incorrect { color:#b91c1c; }
.study-results__list { display:flex; flex-direction:column; gap:8px; }
.study-results__item { display:flex; align-items:center; gap:8px; padding:10px 14px; border-radius:8px; font-size:14px; }
.study-results__item--correct   { background:#f0fdf4; }
.study-results__item--incorrect { background:#fef2f2; }
.study-results__item-front { font-weight:600; color:#111; }
.study-results__item-sep   { color:#9ca3af; flex-shrink:0; }
.study-results__item-back  { color:#374151; }
.study-results__actions { display:flex; gap:12px; justify-content:center; margin-top:32px; }
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/decks/study_sessions_controller.rb \
        app/views/decks/study_sessions/show.html.erb \
        app/assets/stylesheets/app.css
git commit -m "feat: add StudySessionsController and results page"
```

---

### Task 8: Update complete page + deck card badge

**Files:**
- Modify: `app/views/decks/studies/_complete.html.erb`
- Modify: `app/views/decks/_deck.html.erb`
- Modify: `app/controllers/decks_controller.rb`
- Modify: `app/assets/stylesheets/app.css`

- [ ] **Step 1: Update _complete.html.erb to add repeat button**

Replace `app/views/decks/studies/_complete.html.erb`:

```erb
<div class="study-complete">
  <p class="study-complete__emoji">🎉</p>
  <h1 class="study-complete__title">오늘의 학습 완료</h1>
  <p class="study-complete__desc">
    <% if deck.cards.empty? %>
      아직 카드가 없습니다. 카드를 추가하고 학습을 시작해 보세요.
    <% else %>
      오늘 복습할 카드가 없습니다. 내일 다시 확인해 보세요.
    <% end %>
  </p>
  <div class="study-complete__actions">
    <%= link_to deck_path(deck), class: "btn btn--secondary" do %>
      <iconify-icon icon="lucide:arrow-left" width="13"></iconify-icon>
      덱으로 돌아가기
    <% end %>
    <% if deck.cards.any? %>
      <%= link_to deck_study_path(deck, repeat: true), class: "btn btn--primary" do %>
        <iconify-icon icon="lucide:refresh-cw" width="13"></iconify-icon>
        다시 학습하기
      <% end %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Add CSS for study-complete component**

Append to `app/assets/stylesheets/app.css`:

```css
/* study-complete component */
.study-complete { max-width:480px; margin:0 auto; padding:64px 16px; text-align:center; }
.study-complete__emoji   { font-size:3rem; margin:0 0 16px; }
.study-complete__title   { font-size:1.4rem; font-weight:700; color:#111; margin:0 0 8px; }
.study-complete__desc    { color:#6b7280; margin:0 0 28px; }
.study-complete__actions { display:flex; gap:12px; justify-content:center; }
```

- [ ] **Step 3: Update DecksController#index to load session stats**

In `app/controllers/decks_controller.rb`, update the `index` action to add stats preloading inside the `if authenticated?` block, after all deck arrays are set:

```ruby
def index
  @official_decks = Deck.where(scope: :official).includes(:cards).order(:created_at)

  if authenticated?
    @personal_decks = Deck.where(scope: :personal, owner: Current.user)
                          .includes(:cards)
                          .order(updated_at: :desc)
    approved_club_ids = Current.user.club_memberships.approved.pluck(:club_id)
    @show_club_section = approved_club_ids.any?
    @club_decks = @show_club_section ?
      Deck.where(scope: :club, owner_type: "Club", owner_id: approved_club_ids)
          .includes(:cards).order(updated_at: :desc) : []

    all_deck_ids = (@official_decks + @personal_decks + @club_decks).map(&:id)
    @deck_session_stats = Flashcards::DeckSessionStatsQuery.new(
      user: Current.user, deck_ids: all_deck_ids
    ).call
  else
    @personal_decks = []
    @club_decks = []
    @show_club_section = false
    @deck_session_stats = {}
  end
end
```

- [ ] **Step 4: Add stats badge to _deck.html.erb**

Open `app/views/decks/_deck.html.erb`. Replace the existing content:

```erb
<% stats = @deck_session_stats&.dig(deck.id) %>

<div class="deck-card">
  <%= link_to deck, class: "deck-card__body" do %>
    <div class="deck-card__top-row">
      <div class="deck-card__scope-badge deck-card__scope-badge--<%= deck.scope %>">
        <%= { "official" => "공식", "club" => "클럽", "personal" => "내 덱" }[deck.scope] %>
      </div>
      <% if stats&.session_count.to_i > 0 %>
        <div class="deck-card__stats">
          <span><%= stats.session_count %>회</span>
          <% if stats.last_score_pct %>
            <span class="deck-card__stats-score"><%= stats.last_score_pct %>%</span>
          <% end %>
        </div>
      <% end %>
    </div>
    <h3 class="deck-card__title"><%= deck.title %></h3>
    <p class="deck-card__meta">
      <%= deck.cards.size %>장 · <%= deck.updated_at.strftime("%Y.%m.%d") %>
    </p>
  <% end %>
  <div class="deck-card__actions">
    <%= link_to deck_study_path(deck), class: "btn btn--primary btn--sm" do %>
      <iconify-icon icon="lucide:graduation-cap" width="13"></iconify-icon>
      학습하기
    <% end %>
    <%= link_to deck, class: "btn btn--secondary btn--sm" do %>
      카드 보기
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Add CSS for deck-card__top-row and stats badge**

Append to `app/assets/stylesheets/app.css`:

```css
/* deck-card stats badge */
.deck-card__top-row   { display:flex; align-items:center; justify-content:space-between; }
.deck-card__stats     { display:flex; align-items:center; gap:4px; font-size:11px; font-weight:600; color:#6b7280; background:#f9fafb; border:1px solid #e5e7eb; border-radius:99px; padding:2px 8px; }
.deck-card__stats-score { color:#2563eb; }
```

- [ ] **Step 6: Commit**

```bash
git add app/views/decks/studies/_complete.html.erb \
        app/views/decks/_deck.html.erb \
        app/controllers/decks_controller.rb \
        app/assets/stylesheets/app.css
git commit -m "feat: add repeat study button to complete page and session stats badge to deck cards"
```

---

### Task 9: Smoke Test in Browser

- [ ] **Step 1: Start the server**

```bash
bin/dev
```

- [ ] **Step 2: Navigate to flashcard hub**

Open `http://localhost:3000/decks`. Confirm:
- Each deck card that has completed sessions shows "N회 · Z%" badge top-right
- Decks with no sessions show no badge

- [ ] **Step 3: Study a deck end-to-end**

1. Click "학습하기" on any deck with cards
2. Answer all cards (correct or incorrect)
3. Confirm redirect to `/decks/:id/study_sessions/:session_id`
4. Confirm results page shows correct / incorrect card lists
5. Click "다시 학습하기" — confirm all cards appear again
6. Complete repeat session — confirm redirect to results page again

- [ ] **Step 4: Test no-due-cards state**

1. Study a deck normally (SM2 schedules all cards to the future)
2. Return to study — confirm "오늘의 학습 완료" page shows
3. Confirm "다시 학습하기" button is present and works

- [ ] **Step 5: Confirm deck card badge updates**

After completing a session, return to `/decks`. Confirm the deck now shows "1회 · Z%".

- [ ] **Step 6: Run full test suite**

```bash
bundle exec rspec
```

Expected: no regressions in existing specs.

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "chore: verify study session tracking feature complete"
```
