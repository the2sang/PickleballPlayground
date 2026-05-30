---
phase: 03-srs-learning-loop
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - app/controllers/card_reviews_controller.rb
  - app/controllers/decks/browses_controller.rb
  - app/controllers/study_controller.rb
  - app/javascript/controllers/browse_controller.js
  - app/javascript/controllers/study_session_controller.js
  - app/queries/flashcards/global_study_queue_query.rb
  - app/services/flashcards/submit_review_service.rb
  - app/views/card_reviews/_error.html.erb
  - app/views/card_reviews/create.turbo_stream.erb
  - app/views/decks/browses/_card.html.erb
  - app/views/decks/browses/show.html.erb
  - app/views/decks/studies/_card.html.erb
  - app/views/decks/studies/complete.html.erb
  - app/views/decks/studies/show.html.erb
  - app/views/study/complete.html.erb
  - app/views/study/show.html.erb
  - config/routes.rb
  - spec/queries/flashcards/global_study_queue_query_spec.rb
  - spec/requests/card_reviews_spec.rb
  - spec/requests/decks/browses_spec.rb
  - spec/requests/study_spec.rb
  - spec/services/flashcards/submit_review_service_spec.rb
findings:
  critical: 2
  warning: 5
  info: 2
  total: 9
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Reviewed the SRS learning-loop implementation: `CardReviewsController`, `StudyController`, `Decks::BrowsesController`, two Stimulus controllers, two query objects, `SubmitReviewService`, all associated views, routes, and the full spec suite.

The SM-2 algorithm implementation in `Sm2Service` is sound. The Turbo Stream replace pattern is correctly wired. The browse controller correctly restricts the JSON payload to `id/front/back`. The spec suite has good coverage of the happy path.

Two critical defects are present: an IDOR that lets a user create a `CardReview` against any card by omitting `deck_id` from the form submission, and a `render :error` call targeting a partial file (`_error.html.erb`) rather than an action template, which raises `ActionView::MissingTemplate` in the error path.

---

## Critical Issues

### CR-01: IDOR — User Can Rate Any Card by Omitting `deck_id`

**File:** `app/controllers/card_reviews_controller.rb:18-21`

**Issue:** The deck authorization check is wrapped in `if params[:card_review][:deck_id].present?`. An attacker who knows (or enumerates) a foreign card ID can POST to `/card_reviews` with `card_review[card_id]=<foreign_id>` and no `deck_id` parameter. The deck-access guard is skipped entirely. `CardReviewPolicy#create?` passes because it only verifies `record.user == user` (policy is documented as incomplete with a Phase-4 TODO). `SubmitReviewService` then persists a `CardReview` row for a card the user has no read access to.

This also enables card-ID enumeration: a 200 response confirms a card ID exists, regardless of ownership.

The spec at `spec/requests/card_reviews_spec.rb:69-76` tests the foreign-card path but always includes `deck_id: foreign_deck.id` — the actual bypass (omitting `deck_id`) is not covered.

**Fix:** Derive the deck unconditionally from the card itself rather than trusting the parameter, and always authorize it:

```ruby
def create
  @card = Card.find(params[:card_review][:card_id])
  @card_review = CardReview.new(user: Current.user, card: @card)
  authorize @card_review

  # Always derive and authorize the deck from the card — never trust the param
  @deck = @card.deck
  authorize @deck, :show?

  rating = params[:card_review][:rating].to_i
  # ...rest unchanged
end
```

If the study view needs `deck_id` for UI routing purposes, keep the hidden field but ignore it for authorization — use `@card.deck` as the authority.

---

### CR-02: `render :error` Targets a Partial, Not an Action Template

**File:** `app/controllers/card_reviews_controller.rb:37, 53`

**Issue:** Both error branches call `render :error`. Rails resolves a symbol argument as an action template: it looks for `app/views/card_reviews/error.turbo_stream.erb` (for the turbo_stream format) or `app/views/card_reviews/error.html.erb`. Neither file exists. The only file is `app/views/card_reviews/_error.html.erb` — a partial, denoted by the leading underscore. This means both error branches raise `ActionView::MissingTemplate` in production, surfacing as a 500 instead of the intended 422.

The spec at `spec/requests/card_reviews_spec.rb:55-60` uses `.or have_http_status(:bad_request)` as a loose matcher, which would pass even on a 500, masking the failure.

**Fix option A — rename to action templates:**
```
app/views/card_reviews/error.turbo_stream.erb   # wraps a turbo_stream.replace
app/views/card_reviews/error.html.erb
```

**Fix option B — render the partial explicitly:**
```ruby
# in the rescue block and failure branch:
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: turbo_stream.replace("study-card", partial: "error"),
           status: :unprocessable_entity
  end
  format.html { redirect_back_or_to(root_path, alert: "잘못된 평가입니다.") }
end
```

---

## Warnings

### WR-01: `flash.now[:alert]` Is Dead Code in the Turbo Stream Error Branch

**File:** `app/controllers/card_reviews_controller.rb:51`

**Issue:** `flash.now[:alert] = result.errors.join(", ")` is set immediately before a `respond_to` block whose `format.turbo_stream` branch renders the `:error` template. `flash.now` is only visible in the current render cycle through the standard Flash view helper. The `_error.html.erb` partial does not reference `flash` — it displays a hard-coded Korean error string. The assignment is unreachable from the user's perspective in the turbo stream path. In the `format.html` branch below it, the `redirect_back_or_to` call passes `alert: result.errors.join(", ")` independently, so the flash assignment is doubly redundant there too.

**Fix:** Remove line 51 (`flash.now[:alert] = result.errors.join(", ")`). If error detail is ever needed in the turbo-stream error partial, pass it as a local or embed it in a dedicated turbo stream response.

---

### WR-02: Raw SQL String Interpolation in Join Clauses (Both Query Objects)

**File:** `app/queries/flashcards/global_study_queue_query.rb:29-30`
**File:** `app/queries/flashcards/study_queue_query.rb:23-24`

**Issue:** Both query objects build a raw SQL join string with `connection.quote(user.id)`. `connection.quote` does sanitize the value, so this is not currently exploitable. However, the project's `queries.md` rule explicitly states "parameterized queries" as the standard, and this pattern is brittle — a reviewer or future maintainer may miss the sanitization call and copy the pattern without it. The ActiveRecord join API supports a cleaner form.

**Fix:** Use an Arel-based or association-based join that avoids string interpolation:

```ruby
def join_clause
  CardReview.arel_table.create_join(
    CardReview.arel_table,
    CardReview.arel_table.create_on(
      CardReview.arel_table[:card_id].eq(Card.arel_table[:id])
        .and(CardReview.arel_table[:user_id].eq(user.id))
    ),
    Arel::Nodes::OuterJoin
  )
end
# Then: Card.where(deck: accessible_decks).joins(join_clause)...
```

Alternatively, use a subquery or `left_joins` with a scope.

---

### WR-03: `study/show.html.erb` Calls `@due_cards.first.deck` Without Eager Loading

**File:** `app/views/study/show.html.erb:7`

**Issue:** The view calls `@due_cards.first.deck` to pass `deck` to the card partial. `GlobalStudyQueueQuery` returns a relation over `Card` with no `includes(:deck)`. This triggers an additional `SELECT * FROM decks WHERE id = ?` query for every page render. More importantly, if `@due_cards` is empty and the view is rendered (instead of the complete template), `@due_cards.first` returns `nil` and `.deck` raises `NoMethodError`.

Note: `StudyController#show` renders `:complete` when `@due_cards.empty?` — so the nil case may be unreachable today. However, the guard is implicit (a render without return), so any future refactoring that removes the `if` guard will expose the nil dereference.

**Fix:** Add a `return` after the complete render to make the guard explicit, and eager-load deck in the query:

```ruby
# study_controller.rb
def show
  skip_authorization
  @due_cards = Flashcards::GlobalStudyQueueQuery.new(user: Current.user).call
  return render :complete if @due_cards.empty?
end
```

```ruby
# global_study_queue_query.rb — add includes
Card.where(deck: accessible_decks)
    .includes(:deck)
    .joins(join_clause)
    ...
```

The same implicit-return pattern exists in `Decks::StudiesController#show` (line 7–9 of that file) — fix there as well for consistency.

---

### WR-04: `CardReviewsController` Does Not Use Strong Parameters (`card_review_params`)

**File:** `app/controllers/card_reviews_controller.rb:61-66`

**Issue:** The controller defines `card_review_params` as a private method but never calls it. All parameter access throughout `create` is via raw `params[:card_review][:card_id]`, `params[:card_review][:rating]`, and `params[:card_review][:deck_id]`. The strong-parameters method is dead code. While the current manual extractions happen to be safe (each value is individually fetched and type-cast), this is inconsistent with Rails convention and the project's controller rules ("Use strong parameters"), and it means the private method gives a false sense of security to a reader expecting it to be enforced.

**Fix:** Call `card_review_params` in the action, or remove the unused method and document the deliberate inline extraction:

```ruby
def create
  permitted = card_review_params  # use it
  @card = Card.find(permitted[:card_id])
  # derive @deck from @card (see CR-01 fix)
  rating = permitted[:rating].to_i
  ...
end
```

---

### WR-05: `CardReviewPolicy#create?` Incomplete — Acknowledged TODO With Active Security Impact

**File:** `app/policies/card_review_policy.rb:4-9`

**Issue:** The policy contains a documented TODO acknowledging that deck-access is not checked. Combined with CR-01 (which is the primary fix vector), this policy will continue to allow a user to create `CardReview` records for `official` deck cards even after the deck-level authorization is added — because `CardReviewPolicy#create?` will still only check `record.user == user`. Official decks are intentionally accessible to all users, so this may be acceptable, but the Phase-4 TODO note implies intent to add a `DeckPolicy.new(user, record.card.deck).show?` check that will also guard official decks. The policy is incomplete by design, but the gap should be noted here for Phase-4 implementation.

**Fix:** No code change required now. When implementing Phase-4, ensure `DeckPolicy#show?` permits official-deck access before wiring it into `CardReviewPolicy#create?`. Track via the existing TODO comment.

---

## Info

### IN-01: Spec Text Mismatch — `card_reviews_spec.rb` Asserts Wrong String Literal

**File:** `spec/requests/card_reviews_spec.rb:33`

**Issue:** The spec asserts `expect(response.body).to include("오늘의 학습 완료")`. The actual text in `app/views/decks/studies/_complete.html.erb:3` is `"오늘의 학습 완료"` — these match. However, `app/views/study/complete.html.erb` and the global study path render `app/views/study/complete.html.erb` which contains `"오늘의 학습을 모두 마쳤습니다"` (a different string). The deck-study completion path renders the `_complete.html.erb` partial with `"오늘의 학습 완료"`, so the spec passes for the deck-study path. The global study completion tests in `spec/requests/study_spec.rb` correctly use `"오늘의 학습을 모두 마쳤습니다"`. The two completion views have diverged in copy — this is a minor inconsistency that can confuse users who switch between the global and per-deck study modes.

**Fix:** Align the completion message copy across `app/views/study/complete.html.erb` and `app/views/decks/studies/_complete.html.erb`, or document the intentional difference.

---

### IN-02: `GlobalStudyQueueQuery` Hard-Codes `NEW_CARD_LIMIT = 10` Without Configuration

**File:** `app/queries/flashcards/global_study_queue_query.rb:5`
**File:** `app/queries/flashcards/study_queue_query.rb:3`

**Issue:** Both query objects define `NEW_CARD_LIMIT = 10` as independent constants. The values are identical but defined separately, creating a risk of divergence if one is changed without updating the other. The limit also silently controls UX behavior (a user sees at most 10 cards per session) with no way to detect or change this without reading the query source.

**Fix:** Extract to a shared constant in a `Flashcards` module namespace:

```ruby
# app/queries/flashcards/constants.rb or in a Flashcards module
module Flashcards
  DAILY_NEW_CARD_LIMIT = 10
end
```

Both query classes then reference `Flashcards::DAILY_NEW_CARD_LIMIT`.

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
