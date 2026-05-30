---
phase: 03-srs-learning-loop
plan: 03
subsystem: flashcards/srs/global-queue
completed_at: "2026-05-30T07:52:00Z"
duration_minutes: 15
tasks_completed: 1
tasks_total: 1
files_created: 5
files_modified: 0
tags:
  - controller
  - views
  - request-spec
  - srs
  - global-queue
  - pundit

dependency_graph:
  requires:
    - app/queries/flashcards/global_study_queue_query.rb
    - config/routes.rb (GET /study as :study)
    - app/controllers/application_controller.rb
  provides:
    - StudyController#show (GET /study global entry point)
    - app/views/study/show.html.erb
    - app/views/study/complete.html.erb (Pitfall 6 safe, decks_path)
    - app/views/decks/studies/_card.html.erb (minimal stub — Plan 02 expands)
    - spec/requests/study_spec.rb (6 regression guards)
  affects:
    - Wave 2 Plan 02 (Decks::StudiesController + _card.html.erb full implementation)

tech_stack:
  added: []
  patterns:
    - StudyController < ApplicationController (no namespace, D-16)
    - skip_authorization for Pundit verify_authorized future-proofing (A3)
    - GlobalStudyQueueQuery.new(user:).call — personal + official scope
    - decks_path in global complete view (no @deck reference, Pitfall 6 safe)
    - Minimal _card.html.erb stub with data-controller="study-session" mount point

key_files:
  created:
    - app/controllers/study_controller.rb
    - app/views/study/show.html.erb
    - app/views/study/complete.html.erb
    - app/views/decks/studies/_card.html.erb
    - spec/requests/study_spec.rb
  modified: []

decisions:
  - "skip_authorization used (not authorize :application, :study?) — no target resource, future-proof against verify_authorized (D-19, A3)"
  - "Created minimal _card.html.erb stub (Rule 3: blocking dependency) — Plan 02 parallel wave will expand with Stimulus flip/rating UI"
  - "decks_path in complete.html.erb, not deck_path(@deck) — Pitfall 6 (nil @deck NPE prevention)"
  - "font-semibold in complete.html.erb heading — UI-SPEC 2-weight constraint (font-bold prohibited)"

metrics:
  duration_minutes: 15
  completed_date: "2026-05-30"
  examples_added: 6
  suite_total: 491
---

# Phase 3 Plan 3: Global SRS Queue (StudyController + Views + Spec) Summary

**One-liner:** StudyController routes GET /study to personal+official GlobalStudyQueueQuery with Pitfall-6-safe global complete view and T-03-04 regression guard spec.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StudyController + show/complete views + study_spec | 1c2d20c | study_controller.rb, study/show, study/complete, decks/studies/_card, study_spec.rb |

## Commit Log

| Hash | Type | Description |
|------|------|-------------|
| 1c2d20c | feat | StudyController + global study queue views + spec (6 examples) |

## Verification Results

- `bundle exec rspec spec/requests/study_spec.rb` — 6/6 green
- `bundle exec rspec` full suite — 491/491 green
- `bin/rails routes | grep study` — `GET /study study#show` confirmed
- `bin/brakeman --no-pager` — 0 new warnings in new files (3 pre-existing in unrelated files)

## Acceptance Criteria Check

| Criteria | Result |
|----------|--------|
| `grep skip_authorization study_controller.rb` → match | PASS |
| `grep policy_scope study_controller.rb` → no match | PASS |
| `grep GlobalStudyQueueQuery study_controller.rb` → match | PASS |
| `grep "@deck\|deck_path" complete.html.erb` → no match (Pitfall 6) | PASS |
| `grep decks_path complete.html.erb` → match | PASS |
| `grep font-bold complete.html.erb` → no match | PASS |
| `grep font-semibold complete.html.erb` → match | PASS |
| Korean copy strings (3 matches) in complete.html.erb | PASS |
| `grep T-03-04 study_spec.rb` → match | PASS |
| Full suite 0 failures | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing _card.html.erb partial (parallel wave dependency)**
- **Found during:** Task 1 — first rspec run failed with `ActionView::MissingTemplate`
- **Issue:** Plan 03-03 depends on `app/views/decks/studies/_card.html.erb` created by Plan 03-02, but both plans are in Wave 2 (parallel execution). The partial did not exist at the time this plan ran.
- **Fix:** Created a minimal stub partial (`<div data-controller="study-session"><%= card.front %></div>`) sufficient to satisfy Plan 03-03's specs. The stub includes the `data-controller="study-session"` Stimulus mount point per Pitfall 8 (Stimulus Turbo Stream reconnect).
- **Files modified:** `app/views/decks/studies/_card.html.erb` (created — Plan 02 will expand this with full flip/rating UI)
- **Commit:** 1c2d20c (bundled with main task)

## Known Stubs

| File | Line | Content | Reason |
|------|------|---------|--------|
| app/views/decks/studies/_card.html.erb | 1-3 | Shows only `card.front`, no back/ratings | Minimal stub — Plan 02 (wave 2 parallel) creates the full Stimulus-powered card with flip, back reveal, and 4-button rating row |

This stub does NOT prevent Plan 03-03's goal (StudyController routing + global queue scope). Plan 02 will replace this with the full implementation.

## Threat Surface Scan

No new threat surface beyond the plan's threat model:
- T-03-04: Club deck exclusion — verified via regression spec (club context renders complete screen)
- T-03-05: Unauthenticated /study — covered by Authentication concern + spec
- T-03-06: Foreign user personal deck leakage — covered by GlobalStudyQueueQuery WHERE + spec
- T-03-07: Pundit verify_authorized future hardening — `skip_authorization` explicit call

## Self-Check: PASSED
