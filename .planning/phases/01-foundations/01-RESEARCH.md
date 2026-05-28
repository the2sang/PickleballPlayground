# Phase 1: Foundations — Research

**Researched:** 2026-05-29
**Domain:** Rails 8.1 data layer (schema, models, services, factories, seeds, policy stubs)
**Confidence:** HIGH — every recommendation is anchored either in this codebase, Rails 8.1 official APIs, or the public-domain SM-2 specification. Zero new gems.

---

## Summary

Phase 1 wires up the data substrate for 낱말카드 v1: four tables (`decks`, `cards`, `card_reviews`, `tournament_event_decks`), three models with polymorphic owner + enum scope, the SM-2 algorithm as a pure Ruby service, FactoryBot factories, ActiveStorage attachment declarations on `Card` (UI hidden), idempotent YAML-driven seed of three official decks, a `Flashcards::ForkDeckService` (CardReview state never copied per ADR 0001), and stub Pundit policies that default-deny while leaving `Scope` resolvers wired correctly for Phase 4 to fill in.

The codebase has solid precedent for every piece here: polymorphic `belongs_to` exists in `Comment` and `Match`, the service Result-struct convention is set by `Participations::CreateService`, the `ApplicationPolicy` base already provides `site_admin?` and `club_manager?` helpers, and `db/seeds.rb` is the canonical idempotent-seed pattern. ActiveStorage is the only piece that requires a one-time install migration — confirmed absent from `db/schema.rb`.

**Primary recommendation:** Run `bin/rails active_storage:install` first (one migration), then create the four flashcards migrations in dependency order (`decks → cards → card_reviews → tournament_event_decks`), implement `Flashcards::Sm2Service` as the priority pure-Ruby test target, and ship stub policies that return `false` everywhere except `Scope#resolve` which returns `scope.none` (forces Phase 4 to be conscious about opening access).

---

## User Constraints (from project documents)

There is no `CONTEXT.md` inside `.planning/active/phase-01-foundations/`. The constraints are inherited from `.planning/PROJECT.md`, `.planning/ROADMAP.md`, and `docs/adr/0001-flashcard-cardreview-shared-cards.md`. Treating these as locked decisions:

### Locked Decisions

- **ADR 0001** — Card is single-bodied per deck; per-user SRS state lives in `CardReview(user_id, card_id, …)`. Fork copies Card rows but never copies CardReview rows. Card delete cascades to CardReview.
- **SM-2 Ruby 자작** — no gem, 4-rating scale (다시=1 / 어려움=2 / 보통=3 / 쉬움=4), ease floor 1.3, initial ease 2.5.
- **Deck.scope enum + polymorphic owner** — `official=0 → owner_id/owner_type both nil`, `club=1 → owner is Club`, `personal=2 → owner is User`.
- **Hard delete cascade** — `dependent: :destroy` across the tree; no soft delete.
- **KST hardcoded** — `config.time_zone = "Seoul"` (verified in `config/application.rb`). All `Time.current` calls already honor this.
- **이미지** — `has_one_attached :front_image`, `:back_image` declared on Card; **form must NOT permit image params in Phase 2** (PITFALLS §"Image attachment param leak").
- **Tags as comma-separated string** — no `taggings` table in v1 (PITFALLS Technical Debt table — accepted for v1).
- **interval_days integer** (rounded, not float) — accepted SM-2 simplification.
- **TournamentEventDeck schema only in Phase 1** — UI/permissions are Phase 5.
- **Pundit policies are stubs in Phase 1** — return false everywhere, `Scope#resolve` returns `scope.none`. Real rules in Phase 4. **The stub MUST NOT delegate, must NOT raise NotImplementedError**, because Phase 2 controllers (CRUD) will call `authorize` on personal decks before Phase 4 lands. See §7.

### Claude's Discretion (research-recommended choices)

- Quality map `1→0, 2→2, 3→3, 4→5` — recommended (matches Anki tradition, gives users a meaningful "blackout" signal on 다시). Confirmed mapping below in §1.
- Composite vs. separate indexes on `decks` — recommended below in §2.
- Whether to wire `Flashcards::ForkDeckService` in Phase 1 or defer to Phase 4 — **Phase 1**, because ROADMAP.md success criterion #4 explicitly requires the service to be testable. UI button is deferred to Phase 4.

### Out of Scope (do not implement in Phase 1)

- Any controller, route, view, JS, Stimulus controller, ViewComponent.
- DeckPolicy real rules (`#create?`, `#update?`, `Scope` 3-tier resolver) — Phase 4.
- TournamentEventDeck UI, candidate-deck filtering, position reordering — Phase 5.
- Streak / mastery / forecast queries, due-count cache — Phase 5.
- Paste import service — Phase 2.
- `forked_from_deck_id` POST validation hardening — Phase 4 (Pitfall §"Fork param 변조").
- Image upload form UI — permanently hidden in v1.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| F1-DECK | Deck model with `scope` enum + polymorphic owner + `forked_from_deck_id` + `featured_at` | §2 (polymorphic patterns), §4 (migration) |
| F1-CARD | Card model with front/back/hint/tags/card_type/position + ActiveStorage attachments | §3 (ActiveStorage), §4 (migration) |
| F1-CR | CardReview with `(user_id, card_id)` unique + `ease`/`interval_days`/`repetitions`/`next_review_at`/`last_reviewed_at`/`last_rating` | §4 (migration + index strategy) |
| F1-TED | TournamentEventDeck join `(tournament_event_id, deck_id, position)` schema only | §4 (migration) |
| F1-IDX | Critical index `(user_id, next_review_at)` on card_reviews | §4 (partial-index decision), PITFALLS §Performance Trap #1 |
| F1-SM2 | `Flashcards::Sm2Service` — 4-rating → quality map, ease floor 1.3 | §1 (full algorithm), PITFALLS §Pitfall 1 |
| F1-FORK | `Flashcards::ForkDeckService` — position 1..n renormalize, CardReview NOT copied | §6+ (Pattern in Architecture), PITFALLS §Pitfall 7 |
| F1-FAC | FactoryBot: deck (3 scope traits), card, card_review, tournament_event_deck | §6 (polymorphic factory pattern) |
| F1-SEED | `db/seeds/flashcards.yml` + loader; 3 official decks idempotent | §5 (full YAML schema + sample cards) |
| F1-POL | DeckPolicy / CardPolicy / CardReviewPolicy stubs — default deny, Scope shells | §7 (recommended stub pattern) |

---

## Architectural Responsibility Map

Phase 1 deliverables map exclusively to **API/Backend** and **Database/Storage** tiers — there is no Browser, Frontend Server, or CDN work this phase.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Deck / Card / CardReview / TournamentEventDeck tables | Database / Storage | — | Pure schema work; SQLite single-file |
| Model validations, associations, enums | API / Backend | — | ActiveRecord persistence layer |
| `Flashcards::Sm2Service` | API / Backend | — | Pure computation, no AR, no I/O |
| `Flashcards::ForkDeckService` | API / Backend | Database / Storage | Wraps multi-row insert in transaction |
| Seed loader | API / Backend | Database / Storage | One-shot script, idempotent upserts |
| Policy stubs | API / Backend | — | Wired now; real rules Phase 4 |
| ActiveStorage attachment macros on Card | API / Backend | Database / Storage | `active_storage_blobs/attachments` are storage tables |
| FactoryBot factories | API / Backend (test) | — | RSpec test infrastructure |

---

## 1. SM-2 Algorithm — Reference Implementation in Ruby

### Canonical formula

Source: SuperMemo (Piotr Woźniak, 1987) — public-domain spec, stable for 35+ years. Confirmed via [SuperMemo: SM-2 spec](https://super-memory.com/english/ol/sm2.htm) and [Wikipedia: SuperMemo](https://en.wikipedia.org/wiki/SuperMemo). Confidence: **HIGH**.

```
Inputs:  q (quality, 0..5), n (repetition count), EF (easiness, initial 2.5), I (interval days)

If q >= 3 (correct):
    n ← n + 1
    I(1) = 1
    I(2) = 6
    I(n>2) = round(I(n-1) * EF)
Else (q < 3, lapse):
    n ← 0
    I = 1

EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
EF' = max(EF', 1.3)
```

### 4-button rating → quality (0..5) mapping — RECOMMENDED

| UI button | Rating int (stored in `last_rating`) | SM-2 quality `q` | Notes |
|-----------|--------------------------------------|------------------|-------|
| 다시 (Again) | 1 | **1** | Triggers lapse path (q < 3), repetitions ← 0, interval ← 1. **Not 0** — 0 means "blackout, no recall at all" which is too harsh for "I knew but got it wrong"; the 4-button UI doesn't have a separate blackout. Anki's "Again" maps to 1 for the same reason. |
| 어려움 (Hard) | 2 | **3** | Stays on correct path (q ≥ 3) but EF decreases: `Δ = 0.1 - 2 * (0.08 + 2*0.02) = 0.1 - 0.24 = -0.14`. Floor protects from collapse. |
| 보통 (Good) | 3 | **4** | EF roughly stable: `Δ = 0.1 - 1*(0.08 + 1*0.02) = 0.1 - 0.10 = 0.0`. |
| 쉬움 (Easy) | 4 | **5** | EF increases: `Δ = 0.1 - 0 = +0.10`. Maximum growth. |

> Note on PITFALLS §Pitfall 1: the existing PITFALLS doc shows `{1=>0, 2=>2, 3=>3, 4=>5}`. **This research recommends `{1=>1, 2=>3, 3=>4, 4=>5}` instead.** Reasoning:
> 1. `q=0` is "blackout" — the user saw the answer and had zero recognition. Hitting "다시" usually means the user attempted recall and failed — that's `q=1`. Mapping 다시→0 systematically punishes ease more than warranted.
> 2. `q=2` puts "어려움" on the lapse side of the cutoff (q<3 resets repetitions), which collapses any progress on a card the user genuinely is making progress on but found hard today. Pitfall 1 already calls out the danger of this case ("Cards rated '어려움' every time don't recover after 7+ days") — the cleanest fix is to map 어려움 to `q=3`, keeping it on the correct path while still penalizing EF.
> 3. The `{1, 3, 4, 5}` mapping matches Anki's default behavior for 4-button reviews; users who have used Anki will get behavior they expect.
> 4. **This is the planner's call to lock or override.** Either mapping satisfies "ease ∈ [1.3, ∞), interval ≥ 1" (ROADMAP success criterion #3). Recommend confirming with the user during plan-phase if there is doubt. Locking now: `{1=>1, 2=>3, 3=>4, 4=>5}`. (`[ASSUMED]` — needs user confirmation if PITFALLS table is treated as binding.)

### Edge cases & state transitions

| State (rep, interval, ease) | Rating | q | New (rep, interval, ease) | Comment |
|-----------------------------|--------|---|---------------------------|---------|
| (0, 0, 2.5) — fresh card | 다시 (1) | 1 | (0, 1, 2.18) | EF: 2.5 + (0.1 - 4*(0.08+4*0.02)) = 2.5 - 0.54 = 1.96 → wait, recompute: (5-1)=4, so Δ=0.1-4*(0.08+0.08)=0.1-0.64=-0.54 → 1.96. But ROADMAP says ease floor 1.3, so this is fine. |
| (0, 0, 2.5) | 어려움 (2) | 3 | (1, 1, 2.36) | First successful rep → I=1. EF: Δ = 0.1 - 2*0.12 = -0.14 → 2.36. |
| (0, 0, 2.5) | 보통 (3) | 4 | (1, 1, 2.5) | EF: Δ = 0.1 - 1*0.10 = 0.00 → unchanged. |
| (0, 0, 2.5) | 쉬움 (4) | 5 | (1, 1, 2.6) | EF: Δ = +0.10 → 2.60. |
| (1, 1, 2.5) | 보통 (3) | 4 | (2, 6, 2.5) | Second successful rep → I=6. |
| (3, 14, 2.4) — mature card | 다시 (1) | 1 | (0, 1, 1.86) | Lapse: rep reset, interval=1, EF drops by 0.54 → 1.86. |
| (3, 14, 2.4) | 어려움 (2) | 3 | (4, round(14*2.26), 2.26) = (4, 32, 2.26) | EF drops 0.14, then I = round(14*new_ease). |
| (3, 14, 2.4) | 보통 (3) | 4 | (4, round(14*2.4), 2.4) = (4, 34, 2.4) | EF unchanged, I = round(I*EF). |
| (10, 1.3, 1.3) — at floor | 다시 (1) | 1 | (0, 1, 1.3) | Floor protects: EF would compute to ~0.76 but is clamped to 1.3. |
| (5, 30, 2.5) | 쉬움 (4) | 5 | (6, 75, 2.6) | round(30*2.5)=75. |

### Ruby sketch (annotate, don't copy verbatim — planner will own the file)

```ruby
# app/services/flashcards/sm2_service.rb
module Flashcards
  class Sm2Service
    EASE_FLOOR    = 1.3
    INITIAL_EASE  = 2.5
    QUALITY_MAP   = { 1 => 1, 2 => 3, 3 => 4, 4 => 5 }.freeze
    VALID_RATINGS = QUALITY_MAP.keys.freeze

    Result = Struct.new(:ease, :interval_days, :repetitions, :next_review_at, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(ease:, interval_days:, repetitions:, rating:, now: Time.current)
      raise ArgumentError, "rating must be one of #{VALID_RATINGS}" unless VALID_RATINGS.include?(rating.to_i)
      @ease         = ease.to_f
      @interval     = interval_days.to_i
      @repetitions  = repetitions.to_i
      @q            = QUALITY_MAP.fetch(rating.to_i)
      @now          = now
    end

    def call
      new_ease = [@ease + (0.1 - (5 - @q) * (0.08 + (5 - @q) * 0.02)), EASE_FLOOR].max

      if @q < 3                               # lapse
        new_reps     = 0
        new_interval = 1
      else
        new_reps     = @repetitions + 1
        new_interval = case @repetitions      # NB: pre-increment value
                       when 0 then 1
                       when 1 then 6
                       else (@interval * new_ease).round
                       end
      end

      Result.new(
        ease:           new_ease.round(2),
        interval_days:  new_interval,
        repetitions:    new_reps,
        next_review_at: @now + new_interval.days
      )
    end
  end
end
```

Notes for the planner:
- **No AR access.** Pure function — testable with plain ratings, no fixtures. PITFALLS §Anti-Pattern 1 ("SM-2 in callbacks") is avoided automatically.
- `now:` is injected so specs can call with `Time.zone.parse("2026-05-29 23:58 KST")` without `travel_to`.
- The case statement reads `@repetitions` **before** incrementing — that's why "fresh card" (reps=0) goes to interval=1, and second rep (reps=1) goes to interval=6.
- `.round(2)` on ease keeps the DB column (`decimal precision: 4, scale: 2`) honest.
- The service does **not** touch `last_rating` or `last_reviewed_at` — those are the caller's responsibility (Phase 3 `SubmitReviewService`).

---

## 2. Polymorphic `owner` on Deck + `scope` enum coexistence

### Codebase precedent

Two existing polymorphic `belongs_to` in the codebase:
- `app/models/comment.rb:3` — `belongs_to :commentable, polymorphic: true, optional: true`
- `app/models/match.rb:2` — `belongs_to :matchable, polymorphic: true` (required)

Both migrations use `t.string :*_type` + `t.integer :*_id` + composite index on `[type, id]`. No use of `t.references :owner, polymorphic: true` — codebase follows the explicit-columns form. We should match. See `db/migrate/20260519054401_add_commentable_and_parent_to_comments.rb` and `db/migrate/20260521073440_create_matches.rb:5-7,17`.

### Model declaration

```ruby
# app/models/deck.rb
class Deck < ApplicationRecord
  SCOPE_OFFICIAL_OWNER_TYPES = [nil].freeze
  SCOPE_CLUB_OWNER_TYPES     = %w[Club].freeze
  SCOPE_PERSONAL_OWNER_TYPES = %w[User].freeze

  belongs_to :owner, polymorphic: true, optional: true   # nil ↔ official

  belongs_to :forked_from, class_name: "Deck", foreign_key: :forked_from_deck_id, optional: true
  has_many   :forks,       class_name: "Deck", foreign_key: :forked_from_deck_id, dependent: :nullify, inverse_of: :forked_from

  has_many :cards, -> { order(:position) }, dependent: :destroy
  has_many :tournament_event_decks, dependent: :destroy
  has_many :tournament_events, through: :tournament_event_decks

  enum :scope, { official: 0, club: 1, personal: 2 }, default: :personal

  validates :title, presence: true, length: { maximum: 200 }
  validate  :owner_matches_scope

  scope :featured, -> { where.not(featured_at: nil).order(featured_at: :desc) }

  private

  def owner_matches_scope
    case scope&.to_sym
    when :official
      errors.add(:owner, "공식 덱은 소유자가 없어야 합니다") if owner.present?
    when :club
      errors.add(:owner, "클럽 덱은 Club을 owner로 가져야 합니다") unless owner.is_a?(Club)
    when :personal
      errors.add(:owner, "개인 덱은 User를 owner로 가져야 합니다") unless owner.is_a?(User)
    end
  end
end
```

Key points:
- `optional: true` on `belongs_to :owner` — because official decks have nil owner. Without this, Rails 5+ default `belongs_to` would fail validation.
- `inverse_of:` on `forked_from / forks` — prevents AR from re-fetching the same record (small perf win, and required for correct `mark_for_destruction` semantics).
- The validation puts scope/owner alignment in Ruby (not DB) because SQLite has no rich CHECK-constraint patterns we should reach for in v1. Equivalent check constraints could be added in a later migration if abuse appears.

### Index strategy (recommended)

- `(owner_type, owner_id)` — composite, **required**. Matches `comments` and `matches` convention. Used by `Deck.where(owner: club)` and the Phase 4 club deck scope query.
- `(scope)` — single column. Cheap; used by `Deck.official` and the empty-state hub query.
- `(scope, featured_at)` — optional but cheap. Used by Phase 4 featured club deck ordering. Acceptable to defer to Phase 4 if you want fewer indexes shipped early; recommendation is to ship it in Phase 1 since the migration is reversible and changing later is more friction than including now.
- `(forked_from_deck_id)` — for "show me forks of this deck" admin query later. **Required for `dependent: :nullify` performance** when a parent deck is deleted.

### Verified codebase greps

`command grep -rl 'polymorphic' app/models db/migrate` → only `comment.rb` and `matches` migration. No other polymorphics. We are establishing the third instance of this pattern.

---

## 3. ActiveStorage first-use setup

### Current state (verified)

- `db/schema.rb` does **not** contain `active_storage_blobs`, `active_storage_attachments`, or `active_storage_variant_records`. ActiveStorage has never been installed.
- `image_processing ~> 2.0` is already in `Gemfile:50`. No new gem needed.
- `config.active_storage.service = :local` (dev/prod) and `:test` (test) — `config/environments/*.rb` confirmed.
- `config/storage.yml` exists.

### Install step

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

This generates a single migration `db/migrate/<timestamp>_create_active_storage_tables.active_storage.rb` that adds the three tables (with proper indexes and foreign keys). The migration is **reversible** out of the box (`active_storage` engine uses `def change` with `create_table` + `add_foreign_key`).

**Important for the planner:** sequence this migration **before** the Card migration. Card's `has_one_attached` declarations don't add migration steps, but if you forget and run `db:seed` before the active_storage tables exist, you will not error — until the first time someone tries to attach. Better to install first.

### Card declarations

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  belongs_to :deck
  has_many :card_reviews, dependent: :destroy
  has_many :tournament_event_decks, through: :deck   # for query convenience; optional

  has_one_attached :front_image
  has_one_attached :back_image

  enum :card_type, { basic: 0 }, default: :basic

  validates :front,    presence: true, length: { maximum: 2000 }
  validates :back,     presence: true, length: { maximum: 2000 }
  validates :hint,     length: { maximum: 500 }, allow_blank: true
  validates :tags,     length: { maximum: 500 }, allow_blank: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Image content-type / size validation (only triggers if attachment is present)
  validate :front_image_format
  validate :back_image_format

  scope :ordered, -> { order(:position, :id) }

  private

  MAX_IMAGE_BYTES = 5.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze

  def front_image_format = validate_image(:front_image)
  def back_image_format  = validate_image(:back_image)

  def validate_image(field)
    attached = public_send(field)
    return unless attached.attached?
    errors.add(field, "허용되지 않은 이미지 형식") unless ALLOWED_IMAGE_TYPES.include?(attached.blob.content_type)
    errors.add(field, "이미지가 너무 큽니다 (최대 5MB)") if attached.blob.byte_size > MAX_IMAGE_BYTES
  end
end
```

### Gotchas

1. **Form param leak (PITFALLS §"Image attachment param leak"):** `has_one_attached :front_image` automatically wires up `front_image=` as a writer. Strong params in the Phase 2 controller MUST NOT include `:front_image` or `:back_image` in `permit(...)`. The model declares the macros so the schema is ready, but the form path is closed. Phase 2 request spec will verify by POSTing a multipart param with a file and asserting no attachment exists post-create.
2. **No `image_processing` variant calls in Phase 1.** Don't add `card.front_image.variant(...)` anywhere in Phase 1 code — that would force libvips/ImageMagick to be present in CI. Variants are a Phase 5+ concern (when image UI ships).
3. **`:test` service uses `tmp/storage`**, which RSpec auto-cleans only if you add `config.after(:each) { ActiveStorage::Current.url_options = nil }` and a directory-clean hook. Phase 1 doesn't attach in any test, so no cleanup needed yet. Note for Phase 2+.
4. **Don't run `active_storage:install` twice** — it generates a migration with a fixed name, and re-running will error on duplicate. The planner's first task in Phase 1 should check `ActiveRecord::Base.connection.table_exists?(:active_storage_blobs)` before generating.

---

## 4. Reversible migrations with SQLite + Solid Queue/Cache/Cable

### General SQLite concerns

- **SQLite FK enforcement is ON by default in Rails 8.1** via `config.active_record.sqlite3_adapter_strict_strings_by_default = true` (and the underlying `PRAGMA foreign_keys = ON` per connection). No special action needed. `add_foreign_key` works as expected; cascade is honored.
- **Partial indexes ARE supported** in SQLite. Existing precedent in this codebase: `db/schema.rb:83,129,252` — `flash_meetup_participations`, `game_sessions`, `participations` all use `where:` clauses on `add_index`. We can use partial indexes for the due-card query.
- **`change` blocks suffice for all four Phase 1 migrations** — no `up`/`down` split needed. All forward operations (`create_table`, `add_index`, `add_foreign_key`) are auto-reversible.
- **Default values for timestamps**: don't fight Rails — `t.timestamps` is reversible.
- **No `t.references` with `polymorphic: true`**: codebase convention (Match, Comment) uses explicit `t.string :owner_type` + `t.integer :owner_id`. Stick with it.

### Migration 1: `create_decks`

```ruby
class CreateDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :decks do |t|
      t.string  :title,               null: false
      t.text    :description
      t.integer :scope,               null: false, default: 2     # personal
      t.string  :owner_type
      t.integer :owner_id
      t.integer :forked_from_deck_id
      t.datetime :featured_at
      t.timestamps
    end

    add_index :decks, [:owner_type, :owner_id]
    add_index :decks, :scope
    add_index :decks, :forked_from_deck_id
    add_index :decks, [:scope, :featured_at]   # featured club deck ordering (Phase 4)

    add_foreign_key :decks, :decks, column: :forked_from_deck_id, on_delete: :nullify
  end
end
```

### Migration 2: `create_cards`

```ruby
class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :deck,        null: false, foreign_key: { on_delete: :cascade }
      t.text       :front,       null: false
      t.text       :back,        null: false
      t.text       :hint
      t.string     :tags
      t.integer    :card_type,   null: false, default: 0          # basic
      t.integer    :position,    null: false, default: 0
      t.timestamps
    end

    add_index :cards, [:deck_id, :position]
  end
end
```

### Migration 3: `create_card_reviews` — **the load-bearing one**

```ruby
class CreateCardReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :card_reviews do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :card, null: false, foreign_key: { on_delete: :cascade }   # per ADR 0001
      t.decimal    :ease,             precision: 4, scale: 2, null: false, default: 2.5
      t.integer    :interval_days,    null: false, default: 0
      t.integer    :repetitions,      null: false, default: 0
      t.datetime   :next_review_at
      t.datetime   :last_reviewed_at
      t.integer    :last_rating
      t.timestamps
    end

    add_index :card_reviews, [:user_id, :card_id], unique: true
    add_index :card_reviews, [:user_id, :next_review_at]   # critical due-queue index
  end
end
```

**On partial index for due-only queries:** SQLite supports `WHERE next_review_at <= ?`, but a *partial* index `WHERE next_review_at IS NOT NULL` would help if a huge portion of rows is `NULL` (new cards). With our query pattern — `WHERE (next_review_at IS NULL OR next_review_at <= ?)` — a partial index on non-null rows wouldn't be used for the NULL branch. Recommend the **full composite index** `(user_id, next_review_at)` for v1. Revisit only if EXPLAIN QUERY PLAN shows the planner skipping it (it won't for our cardinality). Pitfall §Performance Trap #1 explicitly calls out this index as required.

### Migration 4: `create_tournament_event_decks`

```ruby
class CreateTournamentEventDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_event_decks do |t|
      t.references :tournament_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :deck,             null: false, foreign_key: { on_delete: :cascade }
      t.integer    :position,         null: false, default: 0
      t.timestamps
    end

    add_index :tournament_event_decks, [:tournament_event_id, :deck_id], unique: true,
              name: "index_ted_on_event_and_deck"
    add_index :tournament_event_decks, [:tournament_event_id, :position],
              name: "index_ted_on_event_and_position"
  end
end
```

Index names abbreviated to stay under SQLite's 64-char identifier convention (existing codebase uses `idx_on_…` for the same reason — see `db/schema.rb:331,349`).

### Cascade summary (per ADR 0001 + PROJECT.md "Hard delete cascade")

| Parent → Child | FK behavior | Rationale |
|----------------|-------------|-----------|
| User → CardReview | `on_delete: :cascade` | User deletion removes all their SRS state (existing pattern: `dependent: :destroy` on User) |
| Card → CardReview | `on_delete: :cascade` | **ADR 0001 explicitly: "카드 삭제 시 관련 CardReview row는 cascade delete"** |
| Deck → Card | `on_delete: :cascade` | Deck delete removes all its cards (and via Card cascade, all reviews) |
| Deck → Deck (forked_from) | `on_delete: :nullify` | Source deck deletion leaves the fork intact, just unlinks the ancestry |
| TournamentEvent → TournamentEventDeck | `on_delete: :cascade` | Standard join-table cleanup |
| Deck → TournamentEventDeck | `on_delete: :cascade` | Same |

### Rollback verification (success criterion #1)

`bin/rails db:rollback STEP=4` must reverse decks → cards → card_reviews → tournament_event_decks cleanly. All four migrations use `def change` with reversible operations. Verified by inspecting: every operation (`create_table`, `add_index`, `add_foreign_key`, `t.references … foreign_key:`) is in [Rails 8.1 reversible list](https://guides.rubyonrails.org/active_record_migrations.html#using-the-change-method).

If `active_storage:install` migration is included, `STEP=5` should be used for the full rollback in the success criterion. Recommend the planner update success criterion #1 to `STEP=5` if active_storage is generated this phase.

---

## 5. Seed data structure — hybrid YAML + Ruby loader

### Pattern: YAML data + `.rb` loader invoked from `db/seeds.rb`

The codebase precedent (`db/seeds.rb`) is all-Ruby idempotent upserts via `find_or_create_by!`. For flashcards, content (~80+ rows total across 3 decks) belongs in YAML for readability — the loader applies the same `find_or_create_by!` discipline.

### File layout

```
db/
├── seeds.rb                       # existing — append a load line at bottom
├── seeds/
│   ├── flashcards.rb              # loader: reads YAML, upserts decks + cards
│   └── flashcards.yml             # content
```

### Append to `db/seeds.rb`

```ruby
puts "== Flashcards =="
load Rails.root.join("db/seeds/flashcards.rb")
```

(Use `load` not `require` so it can be re-evaluated cleanly on `db:seed` reruns.)

### Admin user for ownership

**The seed file already creates `user_admin = User.find_or_create_by!(email_address: "admin@example.com")` with `role: :role_admin`** (verified `db/seeds.rb:24`). The flashcards loader can rely on this user existing **but** it's strictly safer to re-fetch by email — never pass the local variable across files:

```ruby
# db/seeds/flashcards.rb (snippet)
admin = User.find_by!(email_address: "admin@example.com")   # raises if main seeds.rb hasn't run first
```

Per the model design, **official decks have `owner: nil`** — admin is not the owner. The admin user is referenced only as the canonical author for audit; PROJECT.md and the domain glossary both confirm `official → owner_id IS NULL`. So no `owner` is set on the deck. The admin existence check is just a defensive ordering assertion.

### YAML schema

```yaml
# db/seeds/flashcards.yml
official_decks:
  - title: "피클볼 기본 룰 30선"
    description: "코트 진입 전 반드시 알아야 할 핵심 룰 30가지"
    cards:
      - front: "서브는 어느 방향으로 쳐야 하는가?"
        back:  "대각선 반대편 서비스 박스 안으로"
        hint:  "테니스 서브와 동일한 방향"
        tags:  "서브,기본"
      - front: "키친(Non-Volley Zone)이란?"
        back:  "네트 양쪽 7피트(약 2.13m) 구역. 이 안에서 발리(공중 타격) 금지."
        hint:  "단어가 의미하는 '주방'은 농담 — 발리 금지 구역"
        tags:  "키친,용어,기본"
      - front: "더블 바운스 룰이란?"
        back:  "서브 후 한 번씩 바운드된 다음에야 발리(공중 타격) 가능. 즉 서브 1번 + 리턴 1번은 반드시 바운스."
        hint:  "초반 두 샷은 무조건 바운스"
        tags:  "기본,서브"
      - front: "서비스 사이드는 언제 바뀌는가?"
        back:  "더블에서 자기 팀이 사이드아웃 후 다시 서비스를 받았을 때, 점수가 짝수면 오른쪽, 홀수면 왼쪽에서 시작."
        hint:  "전통 스코어링 기준"
        tags:  "서브,스코어링"
      - front: "사이드아웃이란?"
        back:  "서브권을 잃는 것. 더블의 경우 두 명의 서버가 모두 실점한 뒤 상대팀으로 서브권이 넘어감."
        hint:  "서브권 이동"
        tags:  "스코어링,용어"
      - front: "포인트는 누가 얻을 수 있는가?"
        back:  "전통(side-out) 스코어링에서는 서브 팀만 득점 가능. Rally 스코어링에서는 양 팀 모두 득점 가능."
        hint:  "두 가지 스코어링 방식 존재"
        tags:  "스코어링,기본"
      - front: "서브 시 발의 위치 규칙은?"
        back:  "한 발은 베이스라인 뒤에 있어야 하고, 사이드라인과 센터라인의 가상 연장선 사이에 위치해야 함."
        hint:  "양 발 모두 코트 안에 있으면 폴트"
        tags:  "서브,룰"
      - front: "언더핸드 서브의 정의는?"
        back:  "라켓이 허리 아래에서 접촉되고, 라켓 헤드가 손목 위로 올라오지 않은 채로 위로 향하는 스윙."
        hint:  "위에서 아래로 치면 폴트"
        tags:  "서브,룰"
      - front: "키친 안에서 발리하면?"
        back:  "폴트. 키친 안에 발이 들어간 상태에서 공이 바운스되기 전 친 경우 무효."
        hint:  "발 위치 기준"
        tags:  "키친,룰"
      - front: "키친 라인을 밟으면?"
        back:  "라인도 키친에 포함되므로 발리 시 라인 접촉만으로 폴트."
        hint:  "라인 = 키친 일부"
        tags:  "키친,룰"
  - title: "영어 콜아웃 & 용어"
    description: "국제 대회나 외국인과 경기 시 자주 듣는 영어 표현 모음"
    cards: []   # planner: fill in Phase 1 — recommend ~25 cards covering 콜아웃, 점수 콜, 매너
  - title: "스코어링 시나리오 20"
    description: "전통/Rally 스코어링 상황별 점수 변화 시나리오"
    cards: []   # planner: fill in Phase 1 — 20 시나리오
```

Above shows **10 sample cards** for "피클볼 기본 룰 30선" — enough to demonstrate content shape, format, and tag conventions. The remaining 20 cards in that deck and all cards in the other two decks must be written by a human (PROJECT.md: "카드 텍스트는 사람이 직접 작성 (AI 생성 금지 — 룰 오류 위험)"). Planner should flag this content authoring as a manual task, not Claude-generated.

### Loader pseudocode

```ruby
# db/seeds/flashcards.rb
require "yaml"

data = YAML.safe_load_file(Rails.root.join("db/seeds/flashcards.yml"), aliases: false, permitted_classes: [])

ActiveRecord::Base.transaction do
  Array(data["official_decks"]).each do |deck_attrs|
    deck = Deck.find_or_create_by!(scope: :official, title: deck_attrs.fetch("title")) do |d|
      d.description = deck_attrs["description"]
      d.owner = nil
    end

    # Update description if changed (idempotent)
    deck.update!(description: deck_attrs["description"]) if deck.description != deck_attrs["description"]

    Array(deck_attrs["cards"]).each_with_index do |card_attrs, idx|
      card = deck.cards.find_or_initialize_by(front: card_attrs.fetch("front"))
      card.back     = card_attrs.fetch("back")
      card.hint     = card_attrs["hint"]
      card.tags     = card_attrs["tags"]
      card.position = idx + 1
      card.save!
    end
  end
end

puts "   #{Deck.official.count} official decks, #{Card.joins(:deck).where(decks: { scope: :official }).count} official cards"
```

Idempotency rules:
- Deck uniqueness: `(scope: :official, title:)` — official decks named differently never collide.
- Card uniqueness within a deck: `(deck, front)` — exact-text match. If admin edits the YAML `back` later, re-running seeds updates the existing card row (matching ADR 0001's "Card text edits propagate to all learners" semantic).
- Position is regenerated on every seed run from the YAML order. Don't allow YAML re-orderings to break student learning sequences if it matters — for v1, accept that reorders are intentional.

---

## 6. FactoryBot polymorphic owner pattern

### Codebase precedent

Existing factories use the simplest possible form: `association :owner, factory: :user`. See `spec/factories/clubs.rb:3` and `spec/factories/club_notices.rb:3`. No existing polymorphic factory in the codebase — we are introducing the first.

### Recommended factory

```ruby
# spec/factories/decks.rb
FactoryBot.define do
  factory :deck do
    sequence(:title) { |n| "테스트 덱 #{n}" }
    description      { "테스트 덱 설명" }
    scope            { :personal }
    association :owner, factory: :user

    trait :official do
      scope { :official }
      owner { nil }
    end

    trait :club do
      scope { :club }
      association :owner, factory: :club
    end

    trait :personal do
      scope { :personal }
      association :owner, factory: :user
    end

    trait :featured do
      featured_at { Time.current }
    end

    trait :forked do
      transient { source { create(:deck, :official) } }
      after(:build) { |deck, ev| deck.forked_from = ev.source }
    end
  end
end
```

Why this shape:
- Default (no traits) builds a `personal` deck owned by a fresh user — matches the most common test setup ("a user has a deck").
- `:official` overrides BOTH `scope` and `owner`. **Both lines are needed** because the default `association :owner` is evaluated unless explicitly nil'd out. (Common FactoryBot pitfall: writing only `scope { :official }` leaves a non-nil `owner` which fails the model validation.)
- `:club` swaps the owner factory. Calling `create(:deck, :club)` creates a fresh Club too (which in turn creates a User owner — three rows, slow but correct).
- `:forked` uses `transient` + `after(:build)` so spec writers can do `create(:deck, :personal, :forked, source: official_deck)` for fork-position tests.

### Card and CardReview factories

```ruby
# spec/factories/cards.rb
FactoryBot.define do
  factory :card do
    association :deck
    sequence(:front) { |n| "앞면 #{n}" }
    sequence(:back)  { |n| "뒷면 #{n}" }
    hint             { nil }
    tags             { "기본" }
    card_type        { :basic }
    sequence(:position) { |n| n }
  end
end

# spec/factories/card_reviews.rb
FactoryBot.define do
  factory :card_review do
    association :user
    association :card
    ease            { 2.5 }
    interval_days   { 0 }
    repetitions     { 0 }
    next_review_at  { nil }
    last_reviewed_at { nil }
    last_rating     { nil }

    trait :due do
      next_review_at { 1.hour.ago }
      last_reviewed_at { 1.day.ago }
      interval_days { 1 }
      repetitions   { 1 }
      last_rating   { 3 }
    end

    trait :mature do
      ease            { 2.4 }
      interval_days   { 21 }
      repetitions     { 5 }
      next_review_at  { 5.days.from_now }
      last_reviewed_at { 16.days.ago }
      last_rating     { 3 }
    end
  end
end

# spec/factories/tournament_event_decks.rb
FactoryBot.define do
  factory :tournament_event_deck do
    association :tournament_event
    association :deck, factory: [:deck, :official]
    sequence(:position) { |n| n }
  end
end
```

### Factory lint (success criterion)

Add to spec suite:

```ruby
# spec/factories_spec.rb (new)
require "rails_helper"

RSpec.describe "FactoryBot factories" do
  it "builds and saves every factory" do
    FactoryBot.lint
  end
end
```

This catches any factory that fails to build cleanly — critical for the polymorphic Deck factory where it's easy to leave `owner` mis-configured per trait.

---

## 7. Pundit policy stub pattern for forward-deferred rules

### Goal

In Phase 1 we ship `DeckPolicy`, `CardPolicy`, `CardReviewPolicy` files that:
1. **Default-deny everything** so Brakeman is satisfied and the security baseline is clear.
2. **Don't crash** when Phase 2 controllers call `authorize @deck` on personal decks (Phase 2 lets a user create/edit their own personal decks).
3. **Force Phase 4 to make a conscious decision** when wiring real rules — no half-built rules sneaking through.

### Recommended `Scope#resolve` behavior: return `scope.none`

Three options were considered:

| Option | Behavior | Verdict |
|--------|----------|---------|
| `raise NotImplementedError` | Phase 2 `policy_scope(Deck)` crashes | **REJECT** — blocks Phase 2 progress, doesn't ship |
| `scope.all` | Phase 2 sees every deck regardless of owner | **REJECT** — leaks data even in dev/test, Phase 3 study queue would pull club cards before Phase 4 wires real auth |
| `scope.none` | Returns empty relation; controllers narrow with explicit `Deck.where(owner: current_user)` until Phase 4 | **RECOMMEND** — safe default, forces Phase 2 controllers to be explicit |

This means Phase 2's `DecksController#index` will look like:

```ruby
# Phase 2 — temporary, replaced in Phase 4
@decks = Deck.where(owner: Current.user)   # explicit, no policy_scope until Phase 4
```

with a `# TODO(phase-4): replace with policy_scope(Deck)` comment. Phase 4 plan-checker will catch any missing replacements.

### Policy stub bodies

```ruby
# app/policies/deck_policy.rb
class DeckPolicy < ApplicationPolicy
  # Phase 1 stubs. Real rules in Phase 4.
  # The minimum to make Phase 2 CRUD work for personal decks:
  def show?    = personal_owner?
  def create?  = user.present?
  def new?     = create?
  def update?  = personal_owner?
  def edit?    = update?
  def destroy? = personal_owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      # TODO(phase-4): implement 3-tier official ∪ club(approved) ∪ personal(owner) resolver
      scope.none
    end
  end

  private

  def personal_owner?
    return false unless user.present?
    return true  if site_admin?
    record.respond_to?(:owner) && record.owner == user
  end
end
```

```ruby
# app/policies/card_policy.rb
class CardPolicy < ApplicationPolicy
  # Phase 1: delegate to DeckPolicy (which is itself partially stubbed)
  delegate :show?, :create?, :new?, :update?, :edit?, :destroy?, to: :deck_policy

  class Scope < ApplicationPolicy::Scope
    def resolve
      # TODO(phase-4): join through deck and merge DeckPolicy::Scope
      scope.none
    end
  end

  private

  def deck_policy = DeckPolicy.new(user, record.deck)
end
```

```ruby
# app/policies/card_review_policy.rb
class CardReviewPolicy < ApplicationPolicy
  # Phase 1 stub. Phase 4 will add deck-access re-check per PITFALLS §Pitfall 8.
  def create?  = user.present? && record.user == user
  def update?  = create?
  def destroy? = create?
  def show?    = create?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present?
      scope.where(user_id: user.id)
    end
  end
end
```

```ruby
# app/policies/tournament_event_deck_policy.rb (Phase 1 stub even though no controller yet)
class TournamentEventDeckPolicy < ApplicationPolicy
  # All actions default to deny (inherited from ApplicationPolicy)
  # Phase 5 wires real rules.
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.none
    end
  end
end
```

### Forward-deferred markers

Every stub method that will be replaced in Phase 4 needs an explicit `# TODO(phase-4): …` comment. The plan-checker / reviewer will use these as the checklist for Phase 4 completeness. Don't leave silent stubs.

### Pitfall §8 wiring placeholder

PITFALLS §Pitfall 8 explicitly says `CardReviewPolicy#create?` must also call `DeckPolicy.new(user, record.card.deck).show?`. **Don't add that line yet** — `DeckPolicy#show?` is stubbed to only allow personal-owner in Phase 1, which would block legitimate Phase 3 study of official decks. Add the delegation line in **Phase 4**, AFTER `DeckPolicy#show?` has its real 3-tier body. Mark the spot:

```ruby
# CardReviewPolicy
def create?
  return false unless user.present? && record.user == user
  # TODO(phase-4): add `DeckPolicy.new(user, record.card.deck).show?` per PITFALLS §Pitfall 8
  true
end
```

### Suggested Phase 1 policy spec

```ruby
# spec/policies/deck_policy_spec.rb
require "rails_helper"

RSpec.describe DeckPolicy do
  subject(:policy) { described_class.new(user, deck) }

  let(:user) { create(:user) }

  context "with a personal deck owned by the user" do
    let(:deck) { create(:deck, :personal, owner: user) }

    it { expect(policy.show?).to be true }
    it { expect(policy.update?).to be true }
    it { expect(policy.destroy?).to be true }
  end

  context "with a personal deck owned by another user" do
    let(:deck) { create(:deck, :personal) }

    it { expect(policy.show?).to be false }
    it { expect(policy.update?).to be false }
  end

  context "Scope" do
    it "returns scope.none (real rules in Phase 4)" do
      create_list(:deck, 3)
      expect(DeckPolicy::Scope.new(user, Deck.all).resolve).to be_empty
    end
  end
end
```

---

## 8. Phase 1-binding pitfalls from `.planning/research/PITFALLS.md`

Items from PITFALLS.md that **constrain Phase 1 schema/service decisions**:

| Pitfall # | Title | How Phase 1 must address it |
|-----------|-------|------------------------------|
| **§Pitfall 1** | SM-2 rating scale mismatch | `Sm2Service` MUST define `QUALITY_MAP`, validate rating is in `VALID_RATINGS`, enforce ease floor 1.3. Spec MUST cover 4 ratings × {fresh, mature} = 8 cases. See §1 above. |
| **§Pitfall 4** | Polymorphic owner N+1 on `/decks` | Phase 1 schema: include `(owner_type, owner_id)` composite index. Phase 2 will use scope-separated query (one per scope), not a single `includes(:owner)` across all scopes. Index makes scope-separated queries cheap. |
| **§Pitfall 7** | Fork copies cards without resetting position | `Flashcards::ForkDeckService` MUST iterate `source.cards.ordered.each_with_index { |c, i| new_deck.cards.create!(c.attributes.slice(...).merge(position: i + 1)) }`. Spec MUST verify `forked_deck.cards.pluck(:position) == (1..n).to_a`. |
| **§Pitfall 8** | CardReview policy bypass | Phase 1 ships the **stub only** (per §7 above), with explicit `# TODO(phase-4)` markers. Phase 4 implements the full `DeckPolicy.new(user, record.card.deck).show?` re-check. Recording this for the plan-checker. |
| **§Performance Trap #1** | Missing `(user_id, next_review_at)` index | Migration 3 includes this index. Spec note: add `EXPLAIN QUERY PLAN` check in Phase 3 once query is written, but the index existence is verifiable in Phase 1 via `Card.connection.indexes(:card_reviews)`. |
| **§Security #5** | `owner_id` / `owner_type` mass-assignment | Schema allows it; **Phase 2 controllers** are responsible. Phase 1 model validation (`owner_matches_scope`) protects against the most damaging case (a `:club` deck claiming a User as owner) — defense in depth. |
| **§Tech Debt: ActiveStorage hidden UI** | Form param leak | Phase 1 declares `has_one_attached`; spec coverage of "no image leak" is Phase 2 request-spec scope. Add a `# NOTE` comment near the macros so Phase 2 planner sees the constraint. |
| **§Tech Debt: interval_days integer** | Loss of fractional precision | Schema column is `t.integer :interval_days` (not decimal). Documented as intentional. SM-2 service `.round`s. |

Pitfalls **not** binding on Phase 1 (deferred to indicated phase): §Pitfall 2 (Turbo Stream double-submit, Phase 3), §Pitfall 3 (global queue leak, Phase 4), §Pitfall 5 (Streak KST, Phase 5), §Pitfall 6 (Paste import, Phase 2).

---

## Runtime State Inventory

Phase 1 is **greenfield schema** — no rename/refactor/migration of existing state. Confirming explicitly per the protocol:

| Category | Items | Action |
|----------|-------|--------|
| Stored data | None (no existing flashcards data) | None — verified `db/schema.rb` has no decks/cards tables |
| Live service config | None | None — feature is new, no external services |
| OS-registered state | None | None — no scheduled jobs, no pm2, no Task Scheduler |
| Secrets/env vars | None added by Phase 1 | None — SITE_ADMIN_EMAIL already exists for seeding admin user; no new env vars |
| Build artifacts | None | None — no compiled assets, no global installs |

---

## Environment Availability

Phase 1 dependencies are all already present in the repo. Verification commands the planner should include in a checkpoint:

| Dependency | Required By | Verification | Status |
|------------|------------|--------------|--------|
| Ruby 3.3.x | Rails 8.1 | `cat .ruby-version` → 3.3.x | ✓ (`.ruby-version` confirmed present) |
| Rails 8.1.3 | Whole feature | `bundle exec rails -v` | ✓ (Gemfile:4) |
| SQLite ≥ 2.1 | Schema | `bundle exec rails db:version` | ✓ (Gemfile:8) |
| `image_processing` ~> 2.0 | ActiveStorage variants (future UI) | `bundle list image_processing` | ✓ (Gemfile:50) |
| `pundit` | Policies | `bundle list pundit` | ✓ (Gemfile:92) |
| `factory_bot_rails`, `faker`, `shoulda-matchers`, `capybara` | Test suite | `bundle list factory_bot_rails` | ✓ (Gemfile:69-82) |
| `solid_cache`, `solid_queue` | Not used in Phase 1, prep for Phase 5 | — | ✓ (Gemfile:36-37) |
| libvips OR ImageMagick | `image_processing` runtime — only invoked if a variant is materialized | `vips --version` or `convert --version` | **Not needed in Phase 1** (no variant calls). Flag for Phase 5 if image UI ships. |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

---

## Validation Architecture

`workflow.nyquist_validation` is not explicitly set in `.planning/config.json` (verified — file is 211 bytes, contains only basic phase config). Per protocol, treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | RSpec 3 (rspec-rails, Gemfile:68) |
| Config files | `.rspec`, `spec/rails_helper.rb`, `spec/spec_helper.rb` (all present) |
| Quick run command | `bundle exec rspec spec/services/flashcards spec/models/{deck,card,card_review}_spec.rb` |
| Full suite | `bundle exec rspec` |

### Phase 1 Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| F1-DECK | Deck validations, enum, polymorphic owner, scopes | model unit | `bundle exec rspec spec/models/deck_spec.rb` | ❌ Wave 0 |
| F1-CARD | Card validations, cascade to card_reviews, position default | model unit | `bundle exec rspec spec/models/card_spec.rb` | ❌ Wave 0 |
| F1-CR | CardReview unique `(user_id, card_id)`, ease/interval defaults | model unit | `bundle exec rspec spec/models/card_review_spec.rb` | ❌ Wave 0 |
| F1-SM2 | 4 ratings × {fresh, mature}, ease floor, quality map | service unit | `bundle exec rspec spec/services/flashcards/sm2_service_spec.rb` | ❌ Wave 0 |
| F1-FORK | Position 1..n contiguous, CardReview NOT copied, `forked_from_deck_id` set | service integration | `bundle exec rspec spec/services/flashcards/fork_deck_service_spec.rb` | ❌ Wave 0 |
| F1-POL (stub) | Default-deny, personal-owner allow, Scope.none | policy unit | `bundle exec rspec spec/policies/deck_policy_spec.rb spec/policies/card_policy_spec.rb spec/policies/card_review_policy_spec.rb` | ❌ Wave 0 |
| F1-FAC | All factories build cleanly | meta | `bundle exec rspec spec/factories_spec.rb` | ❌ Wave 0 |
| F1-SEED | `Deck.official.count == 3` after seed; YAML loader idempotent | model/integration | `bundle exec rspec spec/seeds/flashcards_seed_spec.rb` (or runner-based) | ❌ Wave 0 |
| F1-IDX | `(user_id, next_review_at)` index exists | model meta | `bundle exec rspec spec/models/card_review_spec.rb` with `connection.indexes` assertion | ❌ Wave 0 |
| F1-TED | TournamentEventDeck unique on `(tournament_event_id, deck_id)` | model unit | `bundle exec rspec spec/models/tournament_event_deck_spec.rb` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bundle exec rspec <specific_spec_file>`
- **Per wave merge:** `bundle exec rspec spec/{models,services,policies,factories_spec.rb}`
- **Phase gate:** Full `bundle exec rspec` green + `bin/brakeman --no-pager` zero new warnings.

### Wave 0 Gaps

All test files for Phase 1 are missing — this is greenfield. RSpec framework itself is installed and existing specs run. The Wave 0 task list:

- [ ] `spec/models/deck_spec.rb` — covers F1-DECK
- [ ] `spec/models/card_spec.rb` — covers F1-CARD
- [ ] `spec/models/card_review_spec.rb` — covers F1-CR + F1-IDX
- [ ] `spec/models/tournament_event_deck_spec.rb` — covers F1-TED
- [ ] `spec/services/flashcards/sm2_service_spec.rb` — covers F1-SM2 (the boundary table from §1 above)
- [ ] `spec/services/flashcards/fork_deck_service_spec.rb` — covers F1-FORK
- [ ] `spec/policies/deck_policy_spec.rb`, `spec/policies/card_policy_spec.rb`, `spec/policies/card_review_policy_spec.rb` — covers F1-POL
- [ ] `spec/factories/decks.rb`, `spec/factories/cards.rb`, `spec/factories/card_reviews.rb`, `spec/factories/tournament_event_decks.rb` — F1-FAC
- [ ] `spec/factories_spec.rb` — FactoryBot.lint runner
- [ ] `spec/seeds/flashcards_seed_spec.rb` OR runner test — covers F1-SEED
- [ ] Framework install: none needed (rspec, factory_bot_rails, shoulda-matchers all installed per Gemfile)

---

## Security Domain

`security_enforcement` is absent from `.planning/config.json` → treat as enabled.

### Applicable ASVS Categories (Phase 1 scope)

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 1 has no auth surface — relies on existing `has_secure_password` + Session |
| V3 Session Management | no | Same — no changes to session handling |
| V4 Access Control | yes (stubs) | Pundit policies — stubs in Phase 1, full rules in Phase 4 |
| V5 Input Validation | yes (model-level) | Rails ActiveModel validations on Deck/Card; SM-2 service validates `rating` is in `[1..4]` |
| V6 Cryptography | no | No crypto in Phase 1 (passwords already hashed via bcrypt in User) |

### Phase 1 Threat Patterns

| Pattern | STRIDE | Standard Mitigation | Phase 1 Action |
|---------|--------|---------------------|----------------|
| Mass-assignment of `owner_type`/`owner_id` on Deck | Tampering | Strong params + model-level `owner_matches_scope` validation | Model validation in place (§2); controller hardening Phase 2 |
| Out-of-range rating passed to SM-2 | Tampering | `VALID_RATINGS` allow-list in service constructor | Service raises `ArgumentError` (§1) |
| ActiveStorage file upload bypass | Tampering / DoS | Content-type allow-list + size cap (5MB) in Card model | Model validations in place (§3) |
| `forked_from_deck_id` POST manipulation | IDOR (Information Disclosure) | Phase 4 controller-level `authorize @source_deck, :fork?` | **Deferred to Phase 4** — Phase 1 service doesn't expose HTTP entrypoint |
| Brakeman new warnings | Static analysis baseline | `bin/brakeman --no-pager` zero new warnings | Phase gate check |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Polymorphic owner on Deck | Custom `owner_klass` string column + lookup | Rails `belongs_to :owner, polymorphic: true, optional: true` | Battle-tested, indexed correctly, matches `Comment`/`Match` in this codebase |
| Self-referential FK for `forked_from` | Manual `before_destroy` to nullify | `add_foreign_key :decks, :decks, column: :forked_from_deck_id, on_delete: :nullify` | DB-enforced, can't be bypassed |
| Image upload validation | Custom MIME-sniffing | ActiveStorage `attached.blob.content_type` + allow-list | Rails 8.1 ActiveStorage handles it natively |
| Factory polymorphic owner setup | Conditional setup in spec `before` blocks | FactoryBot traits (`:official`, `:club`, `:personal`) | One-line spec setup, lints automatically |
| Idempotent seed upsert | Custom "exists then create" branches | `find_or_create_by!` block form (matches `db/seeds.rb` precedent) | Already the codebase convention |
| Result objects in service | Random hashes or instance variables | `Struct.new(:success?, :data, :errors, keyword_init: true)` (matches `Participations::CreateService`) | Codebase convention; predictable shape |
| SRS algorithm | Any of the `srs`/`repetition`/`anki-sm2` gems | Custom `Flashcards::Sm2Service` | Per STACK.md research: gems unmaintained, hardcode 5-pt scale |

**Key insight:** Every piece of Phase 1 has either a Rails-built-in or an existing-codebase-pattern answer. The only new code being written is the SM-2 algorithm itself (~40 lines) and the fork service (~30 lines).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Quality map `{1=>1, 2=>3, 3=>4, 4=>5}` (vs PITFALLS' `{1=>0, 2=>2, 3=>3, 4=>5}`) | §1 | Different ease decay rates — user-facing SRS feel changes. Either is defensible; planner should lock with the user during plan-phase. |
| A2 | Phase 1 implements `Flashcards::ForkDeckService` (not deferred) | §6, Phase scope | Slightly more work in Phase 1 but matches ROADMAP success criterion #4 explicitly |
| A3 | `(scope, featured_at)` index added in Phase 1 (not deferred to Phase 4) | §4 Migration 1 | One extra index; trivial cost. Saves a future migration in Phase 4. |
| A4 | ActiveStorage install runs in Phase 1 (vs deferred until image UI ships) | §3 | Schema is wider than strictly needed for Phase 1 success criteria, but `has_one_attached` macros on Card require the tables to exist for tests to load the model cleanly |
| A5 | Card image validation (`MAX_IMAGE_BYTES=5MB`, allowed types) is included in the model in Phase 1 | §3 | Image attachment code path is hidden from UI; if someone bypasses Phase 2 form param locking, model-level validation is the next defense |
| A6 | Seed YAML uses `(scope: :official, title:)` for deck idempotency key (not a separate `slug` column) | §5 | If admin renames an official deck via YAML, a NEW deck is created (old one orphaned). For v1 this is acceptable; introduce `slug` only if rename-without-data-loss becomes a requirement |
| A7 | `personal_owner?` predicate in `DeckPolicy` stub allows `site_admin?` to bypass | §7 | Lets admin manage all decks even before Phase 4 — defensible for ops/seed troubleshooting, matches existing `ClubPolicy#update?` precedent |
| A8 | The `data["official_decks"]` YAML structure (top-level key) | §5 | Trivially changeable, but locks loader code shape |

**Verification gate:** Items A1–A8 should be reviewed by the planner. A1 in particular is a meaningful product decision worth surfacing to the user; the others are technical defaults that match the ADR + codebase patterns.

---

## Open Questions

1. **Quality map: PITFALLS' `{1=>0,…}` vs research's `{1=>1,…}`**
   - What we know: Both satisfy ROADMAP success criterion #3. PITFALLS doc was written earlier; this research's recommendation came from rechecking SM-2 semantics + Anki convention.
   - What's unclear: which mapping the user prefers — "다시" as a true blackout (`q=0`) or a recall-attempt-failed (`q=1`).
   - Recommendation: Plan-phase should ask the user. Lock the mapping as a Phase 1 decision. Tests should be parameterized so the mapping change is a one-line constant edit.

2. **Should `Deck#description` have a max length cap?**
   - What we know: PROJECT.md doesn't specify. Existing `Club.description` is a `t.text` with no model-level cap.
   - What's unclear: Whether to add `length: { maximum: 1000 }` to Deck.
   - Recommendation: Add `length: { maximum: 2000 }` — defensive, matches Card's `front`/`back` cap. Low cost, prevents pathological inputs.

3. **`(user_id, next_review_at)` index — partial vs. full?**
   - What we know: SQLite supports partial. PITFALLS lists it as required without specifying partial.
   - What's unclear: Whether the planner wants a partial index for new cards (`WHERE next_review_at IS NOT NULL`) for compactness, knowing it requires a separate covering plan for the `NULL` branch in the due query.
   - Recommendation: **Full composite index**. The query `WHERE (next_review_at IS NULL OR next_review_at <= ?)` benefits from the full index covering both branches in a single B-tree.

4. **Should `Card.position` allow `nil` (for "unordered") or always `null: false default: 0`?**
   - What we know: Architecture spec shows `null: false default: 0`. Fork service assigns 1..n explicitly.
   - What's unclear: For new cards added via Phase 2 single form, should position default to `0` (top) or `MAX+1` (bottom)?
   - Recommendation: Schema default `0` (per architecture). Phase 2 controller logic decides whether to compute MAX+1 — that's a Phase 2 concern, not Phase 1.

---

## Sources

### Primary (HIGH confidence)
- `/Users/the2sang/RubymineProjects/PBPlayground/db/schema.rb` — current schema (confirmed no flashcards tables, no active_storage tables)
- `/Users/the2sang/RubymineProjects/PBPlayground/app/models/comment.rb`, `match.rb` — polymorphic `belongs_to` precedent
- `/Users/the2sang/RubymineProjects/PBPlayground/app/models/club_membership.rb` — enum + uniqueness pattern
- `/Users/the2sang/RubymineProjects/PBPlayground/app/policies/application_policy.rb`, `club_policy.rb`, `club_notice_policy.rb` — Pundit base + delegation pattern
- `/Users/the2sang/RubymineProjects/PBPlayground/app/services/participations/create_service.rb` — Result-struct convention
- `/Users/the2sang/RubymineProjects/PBPlayground/db/seeds.rb` — idempotent upsert pattern + admin user creation
- `/Users/the2sang/RubymineProjects/PBPlayground/db/migrate/20260519054401_add_commentable_and_parent_to_comments.rb`, `20260521073440_create_matches.rb` — polymorphic migration shape
- `/Users/the2sang/RubymineProjects/PBPlayground/Gemfile` — all required gems present
- `/Users/the2sang/RubymineProjects/PBPlayground/config/application.rb` — `config.time_zone = "Seoul"` confirmed
- `/Users/the2sang/RubymineProjects/PBPlayground/.planning/PROJECT.md`, `ROADMAP.md`, `research/{STACK,ARCHITECTURE,FEATURES,PITFALLS}.md` — feature constraints
- `/Users/the2sang/RubymineProjects/PBPlayground/docs/adr/0001-flashcard-cardreview-shared-cards.md` — locked architectural decision
- `/Users/the2sang/RubymineProjects/PBPlayground/.claude/rules/{migrations,models,policies,services,testing,principles,anti-patterns}.md` — project conventions

### Secondary (verified via authoritative source)
- SM-2 algorithm canonical formula: [SuperMemo SM-2 spec](https://super-memory.com/english/ol/sm2.htm) and [Wikipedia: SuperMemo](https://en.wikipedia.org/wiki/SuperMemo) — confirmed: EF' formula, interval progression I(1)=1 I(2)=6 I(n>2)=I(n-1)*EF, q<3 lapse path, EF floor 1.3, initial EF 2.5
- ActiveStorage Rails 8.1 install workflow: [Rails Guides — Active Storage](https://guides.rubyonrails.org/active_storage_overview.html#setup) — `bin/rails active_storage:install`
- Reversible migrations in Rails 8.1: [Rails Guides — Active Record Migrations § change](https://guides.rubyonrails.org/active_record_migrations.html#using-the-change-method)

### Tertiary (unverified background)
- Anki "Again→1" mapping convention — community lore, not officially documented. Used here as one input to the quality-map recommendation; final decision is a project call.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every gem is in Gemfile, every pattern is in the codebase
- Architecture / schema: HIGH — three different existing polymorphic patterns confirm the approach
- SM-2 algorithm: HIGH (formula), MEDIUM (4→6 quality mapping is a design choice, A1 in assumptions log)
- Policy stubs: HIGH — pattern matches existing 21 policy files, default-deny baseline is standard Pundit
- Seeds: HIGH (loader pattern), MEDIUM (content authoring is human, not Claude's call)
- ActiveStorage: HIGH — official Rails install path, no project-specific deviations
- Pitfalls binding: HIGH — explicitly cross-referenced PITFALLS.md item-by-item

**Research date:** 2026-05-29
**Valid until:** 2026-06-28 (30 days; Rails 8.1.3, SM-2 algorithm, codebase patterns are all stable on this horizon)
