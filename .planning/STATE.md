---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: ready_to_plan
stopped_at: Phase 01 complete (1/1) — ready to discuss Phase 2
last_updated: 2026-05-29T23:16:36.856Z
last_activity: 2026-05-28 -- Phase 01 execution started
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 1
  completed_plans: 1
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-29)

**Core value:** 학습 세션에서 카드를 평가하면 SM-2 알고리즘이 다음 복습 시각을 계산하고 Turbo Stream으로 즉시 다음 카드를 보여준다 — 이 사이클이 끊기면 모든 것이 무의미하다.
**Current focus:** Phase 2 — deck + card crud

## Current Position

Phase: 2
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-29

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 1
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 1 | - | - |

**Recent Trend:** N/A (no plans completed yet)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Key decisions affecting current work:

- **ADR 0001**: Card records are shared across forks — CardReview (not Card copies) holds per-user SRS state. Fork sets `forked_from_deck_id` only.
- **SM-2 quality mapping**: 4-step rating (1–4) maps to SM-2 quality (0–5) via `{ 1 => 0, 2 => 2, 3 => 3, 4 => 5 }`. Enforce `ease >= 1.3` floor.
- **Phase 5 dependency**: Phase 5 (Tournament Integration) depends only on Phase 1. Can execute after Phase 1 if needed.

### Pending Todos

None yet.

### Blockers/Concerns

- **SM-2 scale mismatch** (Phase 1 gate): Must unit-test all 4 ratings × fresh/mature card before Phase 2 proceeds.
- **KST streak boundary** (Phase 4): Use `Time.current.to_date` (not `Date.today`) everywhere. `travel_to` test at 23:58 KST is mandatory.
- **Global study queue access leak** (Phase 3): Queue query MUST join through `DeckPolicy::Scope`, not raw CardReview. Test: revoke membership → `/study` → no club cards.

## Session Continuity

Last session: 2026-05-29
Stopped at: Roadmap written. Ready to begin Phase 1 planning.
Resume file: None
