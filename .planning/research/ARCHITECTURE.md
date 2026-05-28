# Architecture Research

**Domain:** SRS Flashcard System — Rails monolith feature addition
**Researched:** 2026-05-29
**Confidence:** HIGH (derived from existing codebase + Rails conventions)

## Standard Architecture

This is an in-monolith feature. No new services, queues, or infrastructure — everything grafts onto the existing Rails 8.1 + Solid Stack app.

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        Browser (Hotwire)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ Turbo Drive  │  │ Turbo Frames │  │    Turbo Streams      │   │
│  │ (navigation) │  │ (inline edit)│  │ (next-card swap ←★)  │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
├──────────────────────────────────────────────────────────────────┤
│                        Controllers (thin)                        │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌─────────────────┐  │
│  │  Decks   │ │  Cards   │ │CardReviews │ │     Study       │  │
│  └──────────┘ └──────────┘ └────────────┘ └─────────────────┘  │
│                       ↓ authorize (Pundit)                       │
├──────────────────────────────────────────────────────────────────┤
│                        Service Layer                             │
│  ┌────────────┐ ┌──────────────┐ ┌────────────┐ ┌───────────┐  │
│  │ Sm2Service │ │SubmitReview  │ │ForkDeck    │ │ImportCards│  │
│  │ (algorithm)│ │  Service     │ │  Service   │ │  Service  │  │
│  └────────────┘ └──────────────┘ └────────────┘ └───────────┘  │
├──────────────────────────────────────────────────────────────────┤
│                      Models + Queries                            │
│  ┌──────┐ ┌──────┐ ┌────────────┐ ┌──────────────────────────┐ │
│  │ Deck │ │ Card │ │CardReview  │ │    StudyQueueQuery        │ │
│  └──────┘ └──────┘ └────────────┘ └──────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                      SQLite (single file)                        │
│  ┌────────┐ ┌───────┐ ┌─────────────┐ ┌────────────────────┐  │
│  │ decks  │ │ cards │ │card_reviews │ │tournament_event_   │  │
│  │        │ │       │ │             │ │    decks            │  │
│  └────────┘ └───────┘ └─────────────┘ └────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `DecksController` | CRUD + fork action; scope-aware index | Pundit `policy_scope`, `authorize` every action |
| `CardsController` | CRUD nested under deck; paste import preview | Nested resource, `deck.cards.build` |
| `CardReviewsController` | POST-only; returns Turbo Stream with next card | `respond_to format.turbo_stream` |
| `StudyController` | SRS session view + browse view | Loads queue via `StudyQueueQuery` |
| `TournamentEventDecksController` | Deck ↔ tournament event mapping | Nested under `tournament_events` |
| `Deck` model | Scope enum, polymorphic owner, self-referential fork | Validations, scopes, `forked_from` |
| `Card` model | front/back/hint/tags/position; ActiveStorage stubs | `belongs_to :deck`, ordered scope |
| `CardReview` model | SRS state per (user, card); next_review_at | Unique index, `due` scope |
| `Flashcards::Sm2Service` | SM-2 algorithm: rating → new ease/interval/next | Pure Ruby, no side effects, returns struct |
| `Flashcards::SubmitReviewService` | Upsert CardReview, call Sm2Service, bust cache | Result object pattern |
| `Flashcards::ForkDeckService` | Copy Deck + Cards (no CardReview state) | Wrapped in transaction |
| `Flashcards::ImportCardsService` | Parse paste text → bulk create Cards | Validate before save, return failures |
| `StudyQueueQuery` | Due cards for user, optional deck scope | `(user_id, next_review_at)` index |
| `DeckPolicy` | scope-based access/edit/delete rules | Delegates to club membership checks |
| `CardReviewPolicy` | `record.user == current_user` only | Strictest policy in the system |

## Recommended Project Structure

```
app/
├── controllers/
│   ├── decks_controller.rb
│   ├── cards_controller.rb
│   ├── card_reviews_controller.rb
│   ├── study_controller.rb
│   └── tournament_event_decks_controller.rb
├── models/
│   ├── deck.rb
│   ├── card.rb
│   ├── card_review.rb
│   └── tournament_event_deck.rb
├── policies/
│   ├── deck_policy.rb
│   ├── card_policy.rb
│   ├── card_review_policy.rb
│   └── tournament_event_deck_policy.rb
├── services/
│   └── flashcards/
│       ├── sm2_service.rb           # Algorithm only. No AR.
│       ├── submit_review_service.rb # CardReview upsert + cache bust
│       ├── fork_deck_service.rb     # Deck + Card copy (no reviews)
│       ├── import_cards_service.rb  # Paste text → Cards[]
│       └── due_count_cache.rb      # Solid Cache wrapper for badge
├── queries/
│   └── flashcards/
│       ├── study_queue_query.rb     # Due cards, deck-scoped or global
│       └── due_forecast_query.rb    # 7-day bar chart data
├── views/
│   ├── decks/
│   ├── cards/
│   ├── study/
│   │   ├── _card.html.erb           # Turbo Frame target for swap
│   │   └── _complete.html.erb       # Shown when queue empty
│   └── tournament_event_decks/
├── javascript/controllers/
│   ├── card_flip_controller.js      # Front/back toggle (Stimulus)
│   └── paste_import_controller.js   # Preview before submit (Stimulus)
db/
├── migrate/
│   ├── YYYYMMDD_create_decks.rb
│   ├── YYYYMMDD_create_cards.rb
│   ├── YYYYMMDD_create_card_reviews.rb
│   └── YYYYMMDD_create_tournament_event_decks.rb
└── seeds/
    └── flashcards.yml
spec/
├── models/
│   ├── deck_spec.rb
│   ├── card_spec.rb
│   └── card_review_spec.rb
├── requests/
│   ├── decks_spec.rb
│   ├── cards_spec.rb
│   ├── card_reviews_spec.rb
│   └── study_spec.rb
├── services/
│   └── flashcards/
│       ├── sm2_service_spec.rb
│       └── submit_review_service_spec.rb
└── system/
    └── flashcards/
        └── study_session_spec.rb    # Turbo Stream swap, full flow
```

## Database Schema

### `decks`
```
id, title, description,
scope: integer (official=0, club=1, personal=2)  -- null: false, default: 2
owner_type: string, owner_id: integer             -- polymorphic (nil = official)
forked_from_deck_id: integer                      -- FK self-ref, nullable
featured_at: datetime                             -- nil = not featured
created_at, updated_at

Indexes:
  (owner_type, owner_id)                          -- polymorphic lookup
  (scope)                                         -- filtering by scope
  (forked_from_deck_id)                           -- tracing forks
  (featured_at)                                   -- featured ordering
```

### `cards`
```
id, deck_id: integer (null: false, FK)
front: text (null: false)
back: text (null: false)
hint: text
tags: string                                       -- comma-separated
card_type: integer (basic=0)  -- null: false, default: 0
position: integer (null: false, default: 0)
created_at, updated_at

Indexes:
  (deck_id, position)                             -- ordered card listing
```

### `card_reviews`
```
id
user_id: integer (null: false, FK)
card_id: integer (null: false, FK)
ease: decimal (precision: 4, scale: 2, default: 2.5)
interval_days: integer (default: 0)
repetitions: integer (default: 0)
next_review_at: datetime                          -- null = never reviewed (due immediately)
last_reviewed_at: datetime
last_rating: integer                              -- 1-4

Indexes:
  (user_id, card_id) UNIQUE                      -- one state per user/card
  (user_id, next_review_at)                      -- DUE QUEUE — critical
```

### `tournament_event_decks`
```
id
tournament_event_id: integer (null: false, FK)
deck_id: integer (null: false, FK)
position: integer (default: 0)
created_at, updated_at

Indexes:
  (tournament_event_id, deck_id) UNIQUE
  (tournament_event_id, position)
```

## Architectural Patterns

### Pattern 1: Turbo Stream Next-Card Swap (Core Value)

**What:** `CardReviewsController#create` responds with `format.turbo_stream` replacing the `#study-card` frame with the next due card — no page reload, no JavaScript routing.

**When to use:** Every SRS rating action. This is the non-negotiable hot path.

**Implementation:**
```ruby
# app/controllers/card_reviews_controller.rb
def create
  authorize CardReview
  result = Flashcards::SubmitReviewService.call(
    user: Current.user, card: @card, rating: params[:rating].to_i
  )
  @next_card = StudyQueueQuery.new(Current.user, deck: @deck).next_card

  respond_to do |format|
    format.turbo_stream do
      if @next_card
        render turbo_stream: turbo_stream.replace("study-card",
          partial: "study/card", locals: { card: @next_card, deck: @deck })
      else
        render turbo_stream: turbo_stream.replace("study-card",
          partial: "study/complete", locals: { deck: @deck })
      end
    end
  end
end
```

```erb
<%# app/views/study/_card.html.erb %>
<%= turbo_frame_tag "study-card" do %>
  <div data-controller="card-flip">
    <div data-card-flip-target="front"><%= card.front %></div>
    <div data-card-flip-target="back" class="hidden"><%= card.back %></div>
    <div class="rating-buttons">
      <%= button_to "다시(1)", card_reviews_path, params: { card_id: card.id, rating: 1 }, format: :turbo_stream %>
      <%= button_to "어려움(2)", card_reviews_path, params: { card_id: card.id, rating: 2 }, format: :turbo_stream %>
      <%= button_to "보통(3)", card_reviews_path, params: { card_id: card.id, rating: 3 }, format: :turbo_stream %>
      <%= button_to "쉬움(4)", card_reviews_path, params: { card_id: card.id, rating: 4 }, format: :turbo_stream %>
    </div>
  </div>
<% end %>
```

### Pattern 2: SM-2 as Pure Service (No ActiveRecord)

**What:** `Flashcards::Sm2Service` takes current state + rating, returns new state struct. No database access — pure computation.

**Why:** Testable in isolation without DB fixtures. The containing `SubmitReviewService` handles persistence.

**Implementation:**
```ruby
# app/services/flashcards/sm2_service.rb
module Flashcards
  class Sm2Service
    Result = Struct.new(:ease, :interval_days, :repetitions, :next_review_at, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(ease:, interval_days:, repetitions:, rating:)
      @ease         = ease.to_f
      @interval     = interval_days.to_i
      @repetitions  = repetitions.to_i
      @rating       = rating.to_i  # 1-4 mapped to SM-2 q (0-5): 1→1, 2→3, 3→4, 4→5
    end

    def call
      q = SM2_QUALITY_MAP[@rating]
      new_ease = [@ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)), 1.3].max

      if q < 3
        new_reps, new_interval = 0, 1
      else
        new_reps = @repetitions + 1
        new_interval = case @repetitions
                       when 0 then 1
                       when 1 then 6
                       else (@interval * new_ease).round
                       end
      end

      Result.new(
        ease: new_ease.round(2),
        interval_days: new_interval,
        repetitions: new_reps,
        next_review_at: Time.current.in_time_zone("Seoul") + new_interval.days
      )
    end

    SM2_QUALITY_MAP = { 1 => 1, 2 => 3, 3 => 4, 4 => 5 }.freeze
  end
end
```

### Pattern 3: Shared Cards via CardReview Join (ADR 0001)

**What:** When a user forks a deck, `ForkDeckService` copies `Deck` + `Card` records (new deck, same card rows) but does NOT copy `CardReview` rows. The fork creates new Card records with identical content but new IDs so each fork's cards can independently evolve.

**Wait — re-read ADR 0001:** The decision is Card sharing within the SAME deck (admin edits propagate). Fork DOES copy cards. Only `CardReview` SRS state is NOT copied.

**Corrected understanding:**
- Official deck `deck_id=1` has cards `[c1, c2, c3]`
- User forks → new `deck_id=42` with new cards `[c10, c11, c12]` (copied content, new IDs)
- `CardReview` rows are per `(user_id, card_id)` — fork starts fresh, no prior review history
- If admin edits card `c1` in the original deck, fork's `c10` is NOT affected

**Why this matters architecturally:** `CardReview.card_id` references the card in the user's deck (which may be a fork). Authorization: `CardReviewPolicy` checks `review.card.deck` is accessible to current user.

### Pattern 4: Policy Delegation Chain

**What:** `CardPolicy` doesn't duplicate logic — it delegates to the parent deck's policy.

```ruby
# app/policies/card_policy.rb
class CardPolicy < ApplicationPolicy
  delegate :update?, :destroy?, :create?, to: :deck_policy

  def show? = deck_policy.show?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:deck).merge(DeckPolicy::Scope.new(user, Deck.all).resolve)
    end
  end

  private

  def deck_policy = DeckPolicy.new(user, record.deck)
end
```

### Pattern 5: Solid Cache for Due Count Badge

**What:** The nav badge (due card count) is read on every page load. Cache it per user with 1-hour TTL. Bust on any CardReview write or Card/Deck deletion affecting the user.

```ruby
# app/services/flashcards/due_count_cache.rb
module Flashcards
  class DueCountCache
    CACHE_KEY = ->(user_id) { "flashcards/due_count/#{user_id}" }
    TTL = 1.hour

    def self.fetch(user)
      Rails.cache.fetch(CACHE_KEY[user.id], expires_in: TTL) do
        CardReview.where(user: user)
                  .where("next_review_at <= ? OR next_review_at IS NULL", Time.current)
                  .count
      end
    end

    def self.invalidate(user_id)
      Rails.cache.delete(CACHE_KEY[user_id])
    end
  end
end
```

Call `DueCountCache.invalidate(user.id)` inside `SubmitReviewService` after saving.

## Data Flow

### SRS Study Flow (Critical Path)

```
User lands on /decks/:id/study
    ↓
StudyController#show
    → StudyQueueQuery.new(user, deck: deck).first_card
    → renders study/show with turbo_frame "study-card"
    ↓
User flips card (Stimulus card_flip_controller.js)
    → shows back, reveals rating buttons
    ↓
User clicks "보통(3)" → POST /card_reviews (format: turbo_stream)
    ↓
CardReviewsController#create
    → authorize CardReview (CardReviewPolicy: user == current_user, card accessible)
    → SubmitReviewService.call(user:, card:, rating: 3)
        → Sm2Service.call(current state + rating) → new SM-2 state
        → CardReview.find_or_initialize_by(user:, card:).update!(new state)
        → DueCountCache.invalidate(user.id)
    → StudyQueueQuery.new(user, deck: deck).next_card(excluding: card.id)
    ↓
respond_to format.turbo_stream
    → turbo_stream.replace "study-card", partial: "study/card", locals: {card: next_card}
    (or "study/complete" if queue empty)
```

### Deck Fork Flow

```
User clicks "내 덱으로 복사" on official/club deck
    ↓
POST /decks/:id/fork
    ↓
DecksController#fork
    → authorize @deck, :fork?
    → ForkDeckService.call(source_deck: @deck, user: Current.user)
        → transaction:
            new_deck = Deck.create!(scope: :personal, owner: user,
                                    forked_from_deck_id: source.id, ...)
            source.cards.each { |c| new_deck.cards.create!(c.slice(:front,:back,:hint,:tags,:card_type,:position)) }
        → returns Result(success?, deck)
    → redirect_to deck_path(result.deck)
```

### Due Badge Rendering

```
ApplicationController before_action (or layout helper)
    ↓
DueCountCache.fetch(Current.user)
    → cache hit → return count (fast)
    → cache miss → StudyQueueQuery count → store → return count
    ↓
Rendered in nav as badge: <span class="badge"><%= due_count %></span>
```

## Scaling Considerations

| Scale | Concern | Approach |
|-------|---------|----------|
| 0-500 users | None | Monolith is perfect |
| 500-5k users | `card_reviews` table grows (N users × M cards) | `(user_id, next_review_at)` index carries this comfortably in SQLite |
| 5k+ users | Due count queries if badge is uncached | 1-hour Solid Cache TTL handles this; monitor cache hit rate |
| 10k+ users | SQLite write contention on `card_reviews` (high-frequency POST) | Unlikely for this domain; if needed, Solid Queue a background write |

**First bottleneck:** Badge count query without cache. Mitigation: already in design (Solid Cache).
**Second bottleneck:** `card_reviews` table at high user count. The `(user_id, next_review_at)` index keeps queries O(log n). SQLite WAL mode handles concurrent reads.

## Anti-Patterns

### Anti-Pattern 1: Embedding SM-2 in CardReview callbacks

**What people do:** `after_save :recalculate_next_review_at` on `CardReview`

**Why it's wrong:** Callbacks trigger on every save — including admin fixes, bulk imports, seeding. SM-2 should only run on user ratings. Hidden side effect makes tests brittle.

**Do this instead:** Call `Sm2Service` explicitly in `SubmitReviewService#call`. The callback-free path is testable and explicit.

### Anti-Pattern 2: Checking due cards in the view with `card_review.next_review_at < Time.current`

**What people do:** Calling `Time.current` inline in view helpers or scopes without a timezone.

**Why it's wrong:** `Time.current` respects `config.time_zone` but streak logic (midnight boundary) must use KST explicitly. Mixing naive and TZ-aware comparisons causes off-by-one on streak resets.

**Do this instead:** Centralize all time comparisons in `StudyQueueQuery` and `Sm2Service` using `Time.current.in_time_zone("Seoul")`. Never call `Time.now` anywhere.

### Anti-Pattern 3: Loading all cards for a deck to find due ones

**What people do:** `deck.cards.includes(:card_reviews).select { |c| c.due_for?(user) }`

**Why it's wrong:** Loads all cards into Ruby. For a 100-card deck with 1000 users, this is 100K unnecessary AR objects per queue load.

**Do this instead:** `StudyQueueQuery` joins `card_reviews` in SQL:
```ruby
Card.joins("LEFT JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = #{user.id}")
    .where(deck: accessible_decks)
    .where("card_reviews.next_review_at <= ? OR card_reviews.id IS NULL", Time.current)
    .order("card_reviews.next_review_at ASC NULLS FIRST")
```

### Anti-Pattern 4: Polymorphic owner on Deck without scoping

**What people do:** `Deck.where(owner: current_user)` and forgetting club decks the user can access.

**Why it's wrong:** Club decks are owned by the club, not the user. A user with `ClubMembership` (approved, any role) should access club decks without owning them.

**Do this instead:** `DeckPolicy::Scope` resolves all three tiers in one query:
```ruby
class Scope < ApplicationPolicy::Scope
  def resolve
    return scope.none unless user

    club_ids = user.club_memberships.approved.pluck(:club_id)
    scope.where(scope: :official)
         .or(scope.where(scope: :club, owner_type: "Club", owner_id: club_ids))
         .or(scope.where(scope: :personal, owner_type: "User", owner_id: user.id))
  end
end
```

### Anti-Pattern 5: N+1 on cards index with review state

**What people do:** `deck.cards.each { |c| c.card_reviews.where(user: user).first }`

**Why it's wrong:** N queries for N cards.

**Do this instead:** Preload with a user-scoped join:
```ruby
@cards = @deck.cards.order(:position)
              .includes(:card_reviews)
              .where(card_reviews: { user_id: [current_user.id, nil] })
```
Or accept the N+1 for the card list page (non-critical) and profile before optimizing.

## Integration Points

### Existing Models (no changes needed)

| Model | How Flashcards Uses It | Notes |
|-------|------------------------|-------|
| `User` | `CardReview.user_id`, `Deck.owner` polymorphic | No changes to users table |
| `ClubMembership` | `DeckPolicy::Scope` filters club decks by approved membership | Read-only |
| `TournamentEvent` | `TournamentEventDeck` join extends it | Add `has_many :tournament_event_decks` |
| `Club` | `Deck.owner` polymorphic when `scope: :club` | No changes to clubs table |

### Navigation (Utility Dropdown)

Add "낱말카드" link + due badge to the existing utility dropdown partial (same pattern as Pomodoro). The badge renders from `DueCountCache.fetch(current_user)` in the layout.

### Seeds

```yaml
# db/seeds/flashcards.yml
official_decks:
  - title: "피클볼 기본 룰 30선"
    cards:
      - front: "서브는 어느 방향으로 쳐야 하는가?"
        back: "대각선 반대편 서비스 박스 안으로"
  # ...
```

Load via `bin/rails db:seed` — idempotent with `find_or_create_by(title:)` on official decks.

## Sources

- ADR 0001: `docs/adr/0001-flashcard-cardreview-shared-cards.md` (referenced in PROJECT.md)
- SM-2 algorithm: Piotr Woźniak's original 1987 paper (standard implementation)
- Existing codebase patterns: `app/services/participations/create_service.rb`, `app/policies/club_policy.rb`, `app/models/tournament_event.rb`
- Rails 8.1 Turbo Streams: hotwire.dev — `turbo_stream.replace` for partial swaps

---
*Architecture research for: 낱말카드 (Flashcards) v1 — SRS study system*
*Researched: 2026-05-29*
