---
phase: 03-srs-learning-loop
plan: 02
subsystem: flashcards/srs-ui
completed_at: "2026-05-30T07:58:23Z"
duration_minutes: 25
tasks_completed: 2
tasks_total: 2
files_created: 8
files_modified: 4
tags:
  - controller
  - turbo-stream
  - stimulus
  - pundit
  - srs
  - ui

dependency_graph:
  requires:
    - app/services/flashcards/submit_review_service.rb (Plan 01)
    - app/queries/flashcards/study_queue_query.rb (Phase 2 prerequisite)
    - app/controllers/decks/studies_controller.rb (Phase 2 prerequisite)
    - app/policies/card_review_policy.rb (Phase 1)
    - app/policies/deck_policy.rb (Phase 1)
    - config/routes.rb (POST /card_reviews, GET /decks/:id/study — Plan 01)
  provides:
    - CardReviewsController#create (Turbo Stream POST endpoint)
    - app/views/card_reviews/create.turbo_stream.erb (next-card swap)
    - app/views/decks/studies/_card.html.erb (full study card UI with Stimulus)
    - app/javascript/controllers/study_session_controller.js (flip + keyboard + double-submit guard)
    - app/views/decks/studies/_complete.html.erb (completion partial)
    - spec/requests/card_reviews_spec.rb (T-03-01/02/03/05/Race regression guards)
  affects:
    - Wave 2 Plan 03 (StudyController) — same _card and _complete partials
    - Wave 2 Plan 04 (BrowsesController) — study_session_controller.js is NOT used in browse

tech_stack:
  patterns:
    - CardReviewsController: authorize before service call (T-03-01/T-03-03 defense ordering)
    - Turbo Stream replace "#study-card" with next card or _complete partial
    - Stimulus study_session_controller: connect/disconnect keydown pattern (pomodoro analog)
    - D-05 double-submit guard: btn.disabled = true on submitRating (client-side)
    - D-04 keyboard gate: if (!this.flipped) return (Pitfall 3)
    - _complete.html.erb partial extracted from complete.html.erb (enables Turbo Stream render)

key_files:
  created:
    - app/controllers/card_reviews_controller.rb
    - app/views/card_reviews/create.turbo_stream.erb
    - app/views/card_reviews/error.turbo_stream.erb
    - app/views/card_reviews/_error.html.erb
    - app/views/decks/studies/_complete.html.erb
    - app/javascript/controllers/study_session_controller.js
    - spec/requests/card_reviews_spec.rb
  modified:
    - app/views/decks/studies/_card.html.erb (3 lines → 60 lines with full UI)
    - app/views/decks/studies/show.html.erb (added breadcrumb + progress counter)
    - app/views/decks/studies/complete.html.erb (now renders _complete partial)

decisions:
  - "authorize @deck :show? called BEFORE SubmitReviewService — prevents CardReview creation for foreign decks (T-03-01)"
  - "_complete.html.erb partial extracted from complete.html.erb to enable Turbo Stream render (turbo_stream.replace needs _partial)"
  - "StudyQueueQuery (per-deck) used in CardReviewsController (not GlobalStudyQueueQuery) — per-deck context"
  - "error.turbo_stream.erb created as companion template for render :error pattern consistency"

metrics:
  duration: "~25 minutes"
  completed: "2026-05-30T07:58:23Z"
  tasks_completed: 2
  files_modified: 12
---

# Phase 3 Plan 2: SRS Learning Loop UI (Controller + Views + Stimulus) Summary

**One-liner:** CardReviewsController with authorize-before-service T-03-01 defense, Turbo Stream next-card swap, full _card partial with Stimulus study_session_controller (flip/keyboard/double-submit guard).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| Prep | Import Phase 2 prerequisites (blocker fix) | a4422e1 | studies_controller.rb, study_queue_query.rb, studies views, studies_spec |
| 1 | CardReviewsController + Turbo Stream templates + spec | 12cbe34 | card_reviews_controller.rb, create.turbo_stream.erb, error.turbo_stream.erb, _error.html.erb, _complete.html.erb, complete.html.erb, card_reviews_spec.rb |
| 2 | _card.html.erb expansion + show counter + study_session_controller.js | 3100091 | _card.html.erb, show.html.erb, study_session_controller.js |

## Commit Log

| Hash | Type | Description |
|------|------|-------------|
| a4422e1 | chore | Import Phase 2 study prerequisites missing from git (blocking fix) |
| 12cbe34 | feat | CardReviewsController + Turbo Stream templates + spec (Task 1) |
| 3100091 | feat | _card expansion + show counter + study_session_controller.js (Task 2) |

## Verification Results

- `bundle exec rspec spec/requests/card_reviews_spec.rb` — 7/7 green
- `bundle exec rspec spec/requests/decks/studies_spec.rb` — 5/5 green (D-23 maintained)
- `bundle exec rspec` full suite — 497/497 green
- `bin/brakeman --no-pager` — 0 new warnings (3 pre-existing in unrelated files)
- `authorize @card_review` present — T-03-01 guard confirmed
- `policy_scope` not called — D-19 confirmed
- `data-controller="study-session"` on outermost div of _card.html.erb — Pitfall 8 confirmed
- `font-bold` not in complete.html.erb — UI-SPEC typography confirmed
- `text-lg` not in _card.html.erb — UI-SPEC text-base confirmed
- Copywriting: 답 보기 / 다시 / 어려움 / 보통 / 쉬움 / 남은 카드 — UI-SPEC exact match

## Acceptance Criteria Check

| Criteria | Result |
|----------|--------|
| card_reviews_spec.rb 7+ examples green | PASS (7/7) |
| studies_spec.rb 5 examples green | PASS (5/5) |
| authorize @card_review match | PASS |
| front_image/back_image not in permit | PASS (comment only) |
| policy_scope not called | PASS (comment only) |
| brakeman 0 new warnings | PASS |
| data-controller="study-session" in _card outermost | PASS |
| card_reviews_path in _card form | PASS |
| card_id/deck_id/rating hidden fields | PASS (all 3 names present) |
| aria-labels for 다시/어려움/보통/쉬움 | PASS (4 matches) |
| font-bold not in complete.html.erb | PASS |
| font-semibold in _complete.html.erb | PASS |
| text-lg not in _card.html.erb | PASS |
| if (!this.flipped) return D-04 guard | PASS |
| btn.disabled = true D-05 guard | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Phase 2 study prerequisites missing from git**
- **Found during:** Initial setup
- **Issue:** `Decks::StudiesController`, `app/views/decks/studies/` views, `Flashcards::StudyQueueQuery`, and `spec/requests/decks/studies_spec.rb` existed only as untracked working-tree files in the main repo — never committed
- **Fix:** Imported from main repo working tree as a preparatory commit (a4422e1). Content matched Plan 02 interface contract exactly.
- **Files modified:** 6 new files added
- **Commit:** a4422e1

**2. [Rule 2 - Missing Critical] Created _complete.html.erb partial**
- **Found during:** Task 1 implementation
- **Issue:** `render "decks/studies/complete"` (in create.turbo_stream.erb) requires a `_complete.html.erb` partial, but only `complete.html.erb` (full template) existed
- **Fix:** Extracted partial `_complete.html.erb` with content (font-semibold per UI-SPEC); updated `complete.html.erb` to `render "decks/studies/complete", deck: @deck`
- **Files modified:** `_complete.html.erb` (new), `complete.html.erb` (refactored to render partial)
- **Commit:** 12cbe34

**3. [Rule 1 - Bug] authorize @deck :show? moved before SubmitReviewService call**
- **Found during:** Task 1 spec run (T-03-01 test failed)
- **Issue:** Original plan described deck authorization after service call; this allowed `CardReview` record to be created for foreign decks before authorization blocked the request
- **Fix:** Moved `@deck = Deck.find(...)` + `authorize @deck, :show?` BEFORE `Flashcards::SubmitReviewService.call` — prevents foreign-deck CardReview creation
- **Files modified:** `app/controllers/card_reviews_controller.rb`
- **Commit:** 12cbe34

## Known Stubs

None — all data flows are wired. The `_card.html.erb` partial renders real `card.front` and `card.back` from the database. The `_complete.html.erb` partial renders real `deck.cards.empty?` check and `deck_path(deck)` link.

## Threat Surface Scan

No new threat surface beyond what the plan's threat model covers:
- T-03-01: `authorize @card_review` + `authorize @deck, :show?` before service call — implemented
- T-03-02: ArgumentError rescue → 422 — implemented
- T-03-03: Deck.find + authorize @deck :show? blocks deck_id tampering — implemented
- T-03-05: ApplicationController Authentication concern auto-applied — existing
- T-03-Race: Stimulus submitRating btn.disabled=true + SubmitReviewService find_or_initialize_by (Plan 01) — implemented
- T-03-XSS: ERB auto-escaping used throughout, no raw/html_safe calls — maintained

## Self-Check: PASSED

Files exist:
- app/controllers/card_reviews_controller.rb: FOUND
- app/views/card_reviews/create.turbo_stream.erb: FOUND
- app/views/card_reviews/error.turbo_stream.erb: FOUND
- app/views/card_reviews/_error.html.erb: FOUND
- app/views/decks/studies/_complete.html.erb: FOUND
- app/views/decks/studies/_card.html.erb: FOUND (expanded)
- app/views/decks/studies/show.html.erb: FOUND (updated)
- app/javascript/controllers/study_session_controller.js: FOUND
- spec/requests/card_reviews_spec.rb: FOUND

Commits exist:
- a4422e1: FOUND (prerequisites)
- 12cbe34: FOUND (Task 1)
- 3100091: FOUND (Task 2)
