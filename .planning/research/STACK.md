# Stack Research

**Domain:** SRS Flashcard System (Rails monolith feature extension)
**Researched:** 2026-05-29
**Confidence:** HIGH — stack is fully constrained by existing project; no new gems required

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Ruby on Rails | 8.1.3 | Full-stack framework | Already in use; ADR-locked |
| SQLite3 | >= 2.1 | Primary database | Already in use; single-node Solid Stack deployment |
| Turbo Rails | latest | Turbo Streams for next-card swap | Core Value delivery mechanism — rating a card swaps the next card without page reload |
| Stimulus Rails | latest | Card flip, keyboard shortcuts, paste import preview | Client state that doesn't need server round-trips |
| Tailwind CSS 4 | 4.x | Utility-first styling, CSS bar chart for 7-day stats | Already configured; no Node.js build step needed |
| Propshaft + Import Maps | current | Asset pipeline | No Node.js; Stimulus controllers loaded via pin_all_from |
| Solid Cache | current | Due-count badge caching (1hr TTL) | Already installed; no Redis required |
| Solid Queue | current | Background jobs if needed (badge invalidation) | Already installed; SQLite-backed |
| Pundit | current | Authorization: DeckPolicy, CardPolicy, CardReviewPolicy | Already installed; 21 existing policy files as pattern |
| ActiveStorage | Rails built-in | front_image / back_image attachments | Already configured; image_processing gem present |
| bcrypt + has_secure_password | 3.1.7 | Authentication | Already in use; no Devise |

### Supporting Libraries (already installed — no additions needed)

| Library | Version | Purpose | Used For |
|---------|---------|---------|----------|
| `image_processing` | ~> 2.0 | ActiveStorage image variants | front_image / back_image thumbnail display (hidden in v1 UI) |
| `faker` | dev/test | Factory data | CardReview factories, Card seed generation in tests |
| `factory_bot_rails` | dev/test | Test factories | Deck, Card, CardReview factories |
| `shoulda-matchers` | test | One-liner association/validation specs | Card, Deck, CardReview model specs |
| `capybara` + `selenium-webdriver` | test | System tests | SRS study flow end-to-end: rate → next card swap |

### No New Gems Required

The entire flashcard feature builds on the existing dependency set. This is the key finding: **zero new gems needed**.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `brakeman` | Static security analysis | Must pass with 0 new warnings; Pundit `authorize` every action |
| `rubocop-rails-omakase` | Style enforcement | Run after SM-2 service implementation |
| `bundler-audit` | Gem CVE scanning | Run before shipping |

---

## Installation

No new dependencies. All libraries already present in Gemfile.

```bash
# Verify nothing new is needed
bundle check
```

---

## Architecture Decisions for This Feature

### SM-2 Algorithm: Custom Ruby Service (no gem)

**Decision:** Implement `Flashcards::Sm2Service` as a plain Ruby class with a `.call` class method.

**Why no gem:** The `srs` and `repetition` gems on RubyGems are unmaintained and hardcode 5-point Leitner scale. This project uses a 4-rating scale (1=다시/2=어려움/3=보통/4=쉬움) that maps differently to SM-2 quality values. Custom implementation is 30 lines, fully testable, zero external dependency.

```ruby
# Canonical SM-2 quality mapping for this project
QUALITY_MAP = { 1 => 0, 2 => 2, 3 => 3, 4 => 5 }.freeze
```

SM-2 formula inputs: `ease` (EF, starts at 2.5), `repetitions`, `interval_days`. Outputs: updated `ease`, `interval_days`, `next_review_at`.

### Turbo Streams: next-card swap

**Decision:** `POST /card_reviews` returns a Turbo Stream response that replaces `#study-card` with the next due card partial.

This is the Rails-idiomatic pattern for real-time UI updates without a JS framework. The controller checks `turbo_stream?` and responds with `turbo_stream.replace`.

```ruby
respond_to do |format|
  format.turbo_stream { render turbo_stream: turbo_stream.replace("study-card", partial: "next_card") }
  format.html { redirect_to deck_study_path }
end
```

### Card Flip: Stimulus Controller

**Decision:** A `card-flip` Stimulus controller handles the front/back toggle. No JS library needed.

CSS `transform: rotateY(180deg)` with a `flipped` CSS class toggled by the controller. State is local to the DOM — no server round-trip.

### Due-Count Badge: Solid Cache

**Decision:** Cache `user_due_count` with a 1-hour TTL in Solid Cache. Invalidate on `CardReview` create/update and `Card` destroy.

```ruby
Rails.cache.fetch("user_due_count/#{user.id}", expires_in: 1.hour) do
  CardReview.due_for(user).count
end
```

Pattern is consistent with existing Solid Cache usage in the codebase.

### Paste Import: Stimulus + Server Parse

**Decision:** Stimulus controller handles delimiter detection and preview rendering client-side. Form submits raw text to server. Server parses and bulk-inserts cards.

No CSV gem or file upload needed — `textarea` content only.

### 7-Day Due Chart: CSS-only

**Decision:** Pure CSS bar chart using Tailwind height utilities. No charting library.

```erb
<div class="flex items-end gap-1 h-16">
  <% 7.times do |i| %>
    <div class="flex-1 bg-blue-500" style="height: <%= percent %>%"></div>
  <% end %>
</div>
```

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Custom SM-2 service | `srs` gem, `repetition` gem | Unmaintained; hardcoded 5-point scale incompatible with 4-rating requirement |
| Turbo Streams (next-card swap) | Full page reload | Breaks Core Value — seamless card-to-card flow |
| Turbo Streams (next-card swap) | React/Vue component | No Node.js in stack; unnecessary for server-rendered SRS |
| CSS bar chart | Chart.js, Recharts | No npm; overkill for 7 bars |
| Stimulus card flip | Alpine.js | Not in import maps; one Stimulus controller is 10 lines |
| Solid Cache (badge) | Counter cache column | Badge count spans multiple decks — not a single parent count; cache is cleaner |
| SQLite + Solid Queue | Sidekiq + Redis | Explicitly out of scope per project constraints |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Any SRS gem (`srs`, `repetition`, `anki-sm2`) | Unmaintained; wrong rating scale; 30-line custom > opaque dependency | Custom `Flashcards::Sm2Service` |
| Redis | Not in infrastructure; Solid Queue/Cache covers all needs | Solid Cache + Solid Queue |
| React / Vue / Alpine.js | Not in import maps; adds build complexity | Stimulus + Turbo Streams |
| Chart.js / Recharts | npm dependency; CSS bar chart is sufficient for 7 bars | Tailwind CSS height utilities |
| Devise | Already using has_secure_password + custom auth | Existing auth system |
| `acts_as_list` gem | position column management for Card ordering | Manual `position` integer + scope-based reorder |
| i18n yml | Explicitly out of scope; existing pattern is hardcoded Korean | Hardcoded Korean strings in views |
| CSV upload / `roo` gem | Already installed for other use; Paste import is simpler for cards | Textarea paste import (Stimulus) |
| Soft delete (`discard`, `paranoia`) | Out of scope per PROJECT.md; existing pattern is hard delete | `dependent: :destroy` cascade |

---

## Schema Implications for Stack Choices

### Critical Index

```sql
-- Required by PROJECT.md constraints; drives due-card queue performance
CREATE INDEX idx_card_reviews_user_next ON card_reviews (user_id, next_review_at);
```

Without this index, `CardReview.where(user: current_user).where("next_review_at <= ?", Time.current)` degrades linearly with review count.

### Polymorphic owner on Deck

```ruby
belongs_to :owner, polymorphic: true, optional: true  # nil = official deck
```

`official` decks have `owner: nil`. `club` decks have `owner: club`. `personal` decks have `owner: user`. This avoids a separate table per scope.

### ActiveStorage Attachments (Schema Only)

Migrations create `has_one_attached :front_image` and `has_one_attached :back_image` on Card. The `active_storage_attachments` and `active_storage_blobs` tables already exist (Rails built-in). No migration needed for the tables — only the model declarations. UI upload forms are hidden behind a feature condition until S3 is configured.

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `turbo-rails` latest | Rails 8.1 | Turbo 8 ships with Rails 8; `turbo_stream.replace` API stable |
| `stimulus-rails` latest | Import Maps | `pin_all_from "app/javascript/controllers"` auto-loads controllers |
| `solid_cache` | SQLite3 >= 2.1 | Uses WAL mode; no config changes needed for new cache keys |
| `pundit` current | Rails 8.1 | `authorize` + `policy_scope` API unchanged |
| `image_processing` ~> 2.0 | ActiveStorage | Requires libvips or ImageMagick; already configured |

---

## Sources

- Project constraints in `.planning/PROJECT.md` — stack explicitly locked (HIGH confidence)
- Existing `Gemfile` — all listed gems confirmed present (HIGH confidence)
- `config/importmap.rb` — confirmed JS surface: Turbo, Stimulus, marked, lexxy only (HIGH confidence)
- SM-2 algorithm: Piotr Woźniak's original 1987 specification (public domain) — formula stable for 35+ years (HIGH confidence)
- Rails 8.1 Turbo Streams API: official Turbo documentation (HIGH confidence)

---
*Stack research for: 낱말카드 (Flashcards) SRS feature on PBPlayground*
*Researched: 2026-05-29*
