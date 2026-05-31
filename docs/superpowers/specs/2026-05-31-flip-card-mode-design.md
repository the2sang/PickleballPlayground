# Flip Card Mode (주관식 학습) — Design Spec

**Date:** 2026-05-31
**Status:** Approved

---

## Overview

Add a subjective flashcard flip mode alongside the existing 4-option MCQ study mode.
Users can browse cards front→back with a 3D flip animation, rate each card's difficulty (1–5 stars), and filter study sessions by difficulty in both flip and MCQ modes.

---

## 1. Data Model

### New table: `user_card_ratings`

| column     | type    | constraints              |
|------------|---------|--------------------------|
| id         | integer | PK                       |
| user_id    | integer | NOT NULL, FK → users     |
| card_id    | integer | NOT NULL, FK → cards     |
| difficulty | integer | NOT NULL, 1–5            |
| created_at | datetime | NOT NULL                |
| updated_at | datetime | NOT NULL                |

- UNIQUE INDEX on `(user_id, card_id)`
- Model: `UserCardRating`
- `CardReview` (SRS) is unchanged — difficulty is stored separately

---

## 2. Routes

```
GET  /decks/:deck_id/flip              → Decks::FlipsController#show
POST /decks/:deck_id/card_ratings      → Decks::CardRatingsController#upsert
```

Optional query param: `?min_stars=N` (1–5) filters cards by minimum difficulty rating.

Existing MCQ route also accepts `?min_stars=N`:
```
GET  /decks/:deck_id/study?min_stars=N → Decks::StudiesController#show
```

---

## 3. Controllers

### `Decks::FlipsController#show`

```ruby
def show
  @deck  = Deck.find(params[:deck_id])
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

  @ratings = UserCardRating.where(user: Current.user, card: @cards)
                            .pluck(:card_id, :difficulty).to_h
end
```

Renders empty state when `@cards` is empty.

### `Decks::CardRatingsController#upsert`

```ruby
def upsert
  @card = Card.find(params[:card_id])
  @deck = Deck.find(params[:deck_id])
  authorize @deck, :show?

  rating = UserCardRating.find_or_initialize_by(user: Current.user, card: @card)
  rating.update!(difficulty: params[:difficulty].to_i.clamp(1, 5))

  head :ok
end
```

### `Decks::StudiesController#show` — changes

Add `min_stars` filtering before building `@due_cards`:

```ruby
min_stars = params[:min_stars].to_i
if min_stars.between?(1, 5)
  rated_ids = UserCardRating.where(user: Current.user, difficulty: min_stars..)
                             .where(card: @deck.cards)
                             .pluck(:card_id)
  @due_cards = @due_cards.where(id: rated_ids)
end
```

---

## 4. Views

### New files

```
app/views/decks/flips/
  show.html.erb        # Flip study page
  _card.html.erb       # Card partial (front + back faces)

app/javascript/controllers/
  flip_card_controller.js
```

### Flip page layout

```
Header: ← [Deck title]                    [주관식 학습 chip]
Body:
  난이도: ★★★☆☆   (clickable stars)
  ┌──────────────────────────────────────┐
  │                                      │
  │   PER (주가수익비율)                   │  ← front face
  │                                      │
  │      클릭해서 정답 확인               │
  └──────────────────────────────────────┘

  [← 이전]        5 / 30        [다음 →]

After click (flipped):
  ┌──────────────────────────────────────┐
  │  주가 ÷ EPS. 낮을수록 저평가 가능성. │  ← back face
  │                                      │
  │              ③ ② ①                  │  ← countdown
  └──────────────────────────────────────┘
```

### Deck show page — button changes

```
기존: [학습 시작]  [훑어보기]

변경: [학습 시작 ▾]  [주관식 학습 ▾]  [훑어보기]
           ↓               ↓
       전체 카드        전체 카드
       ★이상           ★이상
       ★★이상          ★★이상
       ★★★이상         ★★★이상
       ★★★★이상        ★★★★이상
       ★★★★★          ★★★★★
```

- Dropdown hidden when user has zero rated cards for this deck.

### Empty state (filter returns no cards)

```
"★★★이상 카드가 아직 없습니다. 주관식 학습으로 별점을 먼저 등록해보세요."
[전체 카드로 학습하기]
```

---

## 5. Stimulus Controller: `flip_card_controller.js`

### Values & Targets

```javascript
static values  = { cards: Array, ratings: Object, deckId: Number }
static targets = ["front", "back", "inner", "counter",
                  "prevBtn", "nextBtn", "star", "countdown"]
```

### State

```javascript
index = 0          // current card index
flipped = false    // is card showing back?
autoFlipTimer = null
countdownTimer = null
```

### Methods

| Method | Behaviour |
|--------|-----------|
| `flip()` | Toggle `--flipped` CSS class on inner element. If flipping to back: start 3s auto-flip-back timer + countdown. If flipping to front: cancel timers. |
| `autoFlipBack()` | Called after 3s; flips card back to front. |
| `navigate(dir)` | Cancel timers, reset to front face, update index, swap front/back text, update counter & star display, toggle prev/next disabled. |
| `rate(stars)` | Update star highlight optimistically; POST to `/decks/:id/card_ratings` with `{ card_id, difficulty: stars }`; update local ratings map. |

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `Space` / `Enter` | Flip |
| `←` | Previous |
| `→` | Next |
| `1`–`5` | Set star rating |

### CSS (added to existing stylesheet)

```css
.flip-card            { perspective: 1000px; cursor: pointer; }
.flip-card__inner     { transition: transform 0.45s ease; transform-style: preserve-3d;
                        position: relative; min-height: 220px; }
.flip-card__inner--flipped { transform: rotateY(180deg); }
.flip-card__front,
.flip-card__back      { backface-visibility: hidden; position: absolute; inset: 0; }
.flip-card__back      { transform: rotateY(180deg); }
```

> `min-height: 220px` — front/back are absolutely positioned inside inner; inner needs explicit height so the card doesn't collapse.

---

## 6. Policy

`Decks::FlipsController` and `Decks::CardRatingsController` both call `authorize @deck, :show?` — no new policy methods needed.

---

## 7. Testing

| Layer | What to test |
|-------|-------------|
| Model | `UserCardRating` uniqueness, difficulty range (1–5) |
| Controller | `FlipsController#show` with/without `min_stars`; empty-state; upsert creates & updates |
| System | Flip animation triggers; auto-flip after 3s; star rating persists on reload; prev/next navigation; keyboard shortcuts |

---

## 8. Out of Scope

- Image attachments on flip cards (deferred, same as MCQ mode)
- Sorting cards by difficulty in flip mode (can be added later via URL param)
- Difficulty stats / analytics dashboard
