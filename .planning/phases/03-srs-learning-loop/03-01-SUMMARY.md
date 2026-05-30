---
phase: 03-srs-learning-loop
plan: 01
subsystem: flashcards/srs
completed_at: "2026-05-30T07:43:00Z"
duration_minutes: 20
tasks_completed: 2
tasks_total: 2
files_created: 4
files_modified: 1
tags:
  - service
  - query
  - routes
  - tdd
  - sm2
  - srs

dependency_graph:
  requires:
    - app/services/flashcards/sm2_service.rb
    - app/models/card_review.rb
    - app/queries/flashcards/study_queue_query.rb
  provides:
    - Flashcards::SubmitReviewService (.call interface)
    - Flashcards::GlobalStudyQueueQuery (.new(user:).call interface)
    - POST /card_reviews route
    - GET /study route
    - GET /decks/:id/browse route
  affects:
    - Wave 2 controllers (CardReviewsController, StudyController, Decks::BrowsesController)

tech_stack:
  patterns:
    - PORO service with Result Struct (no ApplicationService inheritance)
    - Query object with LEFT OUTER JOIN for new-card detection
    - find_or_initialize_by + update! for upsert
    - RecordNotUnique rescue with find_by! recovery (no bare retry)
    - nil coalescing for SM-2 initial values (ease||2.5, interval_days||0, repetitions||0)

key_files:
  created:
    - app/services/flashcards/submit_review_service.rb
    - app/queries/flashcards/global_study_queue_query.rb
    - spec/services/flashcards/submit_review_service_spec.rb
    - spec/queries/flashcards/global_study_queue_query_spec.rb
  modified:
    - config/routes.rb

decisions:
  - "PORO only — no ApplicationService inheritance (D-21)"
  - "Explicit Deck WHERE clause, no policy_scope (D-19 — DeckPolicy::Scope returns scope.none)"
  - "SM-2 QUALITY_MAP {1=>1, 2=>3, 3=>4, 4=>5} from code is source of truth (Assumption A1)"
  - "RecordNotUnique rescue uses find_by! recovery — bare retry forbidden (Pitfall 9)"
  - "nil coalescing in SubmitReviewService (Pitfall 7) — CardReview model NOT modified"
  - "club deck excluded from global queue until Phase 4 (T-03-04, D-17 TODO marker)"
---

# Phase 3 Plan 1: Backend Foundation (Service + Query + Routes) Summary

**One-liner:** SM-2 CardReview upsert service (PORO + RecordNotUnique recovery) and personal/official-only global study queue query, with 3 Phase 3 routes activated for Wave 2 parallel execution.

## Tasks Completed

| Task | Name | Commits | Files |
|------|------|---------|-------|
| 1 | Flashcards::SubmitReviewService | 58b135a (RED), c910329 (GREEN) | submit_review_service.rb + spec |
| 2 | Flashcards::GlobalStudyQueueQuery + Routes | fe0621a (RED), 0dcc6a7 (GREEN) | global_study_queue_query.rb + spec + routes.rb |

## Commit Log

| Hash | Type | Description |
|------|------|-------------|
| 58b135a | test | RED: failing spec for SubmitReviewService (12 examples) |
| c910329 | feat | GREEN: SubmitReviewService PORO implementation |
| fe0621a | test | RED: failing spec for GlobalStudyQueueQuery (12 examples) |
| 0dcc6a7 | feat | GREEN: GlobalStudyQueueQuery + 3 routes |

## Verification Results

- `bundle exec rspec spec/services/flashcards/submit_review_service_spec.rb` — 12/12 green
- `bundle exec rspec spec/queries/flashcards/global_study_queue_query_spec.rb` — 12/12 green
- `bundle exec rspec` full suite — 490/490 green (5 studies_spec examples included)
- `POST /card_reviews`, `GET /study`, `GET /decks/:deck_id/browse` all routed
- `bin/brakeman --no-pager` — 0 new warnings in new files

## Acceptance Criteria Check

| Criteria | Result |
|----------|--------|
| SubmitReviewService 0 failures | PASS |
| `grep ApplicationService submit_review_service.rb` — no inheritance | PASS (comment only) |
| `grep rescue.*RecordNotUnique` — match | PASS |
| `grep retry` — no bare retry | PASS (comment only) |
| `grep "|| 2.5"` — nil coalescing | PASS |
| GlobalStudyQueueQuery 0 failures | PASS |
| club deck exclusion context exists | PASS |
| `grep policy_scope global_study_queue_query.rb` — no call | PASS (comment only) |
| `grep "TODO(phase-4)"` — match | PASS |
| `POST /card_reviews` in routes | PASS |
| `GET /study` (top-level, no namespace) | PASS |
| `GET /decks/:deck_id/browse` | PASS |
| Full suite green including studies_spec | PASS |

## Deviations from Plan

None — plan executed exactly as written.

## TDD Gate Compliance

Both tasks followed strict RED/GREEN TDD:
- RED: spec fails with NameError (uninitialized constant)
- GREEN: implementation passes all examples

| Task | RED commit | GREEN commit |
|------|-----------|--------------|
| Task 1 | 58b135a | c910329 |
| Task 2 | fe0621a | 0dcc6a7 |

## Known Stubs

None — no placeholder data, no hardcoded empty values in new files.

## Threat Surface Scan

No new threat surface beyond what the plan's threat model already covers:
- T-03-01: Controller authorization (Wave 2 responsibility)
- T-03-02: ArgumentError from Sm2Service for invalid ratings (tested in spec)
- T-03-04: Club deck exclusion regression guard in query spec
- T-03-Race: RecordNotUnique recovery (no bare retry) implemented and tested

## Self-Check: PASSED

Files exist:
- app/services/flashcards/submit_review_service.rb: FOUND
- app/queries/flashcards/global_study_queue_query.rb: FOUND
- spec/services/flashcards/submit_review_service_spec.rb: FOUND
- spec/queries/flashcards/global_study_queue_query_spec.rb: FOUND

Commits exist:
- 58b135a: FOUND
- c910329: FOUND
- fe0621a: FOUND
- 0dcc6a7: FOUND
