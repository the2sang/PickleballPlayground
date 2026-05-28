# Project Research Summary

**Project:** 낱말카드 (Flashcards) — SRS 플래시카드 시스템
**Domain:** In-monolith SRS feature extension for a Rails 8.1 pickleball community app
**Researched:** 2026-05-29
**Confidence:** HIGH

## Executive Summary

This is a Spaced Repetition System (SRS) flashcard feature being grafted onto PBPlayground, an existing Rails 8.1 monolith. The stack is fully constrained by the project — zero new gems are required. The entire feature builds on Turbo Streams (next-card swap), Stimulus (card flip, paste import), Pundit (authorization), Solid Cache (due-count badge), and a custom 30-line SM-2 Ruby service. No Redis, no Node.js, no charting library. The integration surface is three existing models: `User`, `ClubMembership`, and `TournamentEvent`.

The recommended approach is a four-phase delivery: foundation first (models, SM-2 service, Pundit policies), then the core study loop (SRS session + Turbo Streams), then statistics, then platform integrations (tournament events, club nudges). This order is dictated by hard dependencies — the SM-2 service must exist before the study loop, the study loop must accumulate `CardReview` data before statistics are meaningful, and tournament/club integrations are independently addable once the core works.

The single highest-risk item is the SM-2 rating scale mismatch: the canonical algorithm expects quality 0–5, but this project uses a 4-step rating (1–4). Without an explicit quality mapping and an `ease >= 1.3` floor guard, cards rated "어려움" repeatedly will lock into an infinite daily loop. This must be caught with unit tests covering all four ratings on both fresh and mature cards before the study loop is built on top of it.

## Key Findings

### Recommended Stack

The stack is locked — no additions required. All libraries are already installed in the Gemfile.

**Core technologies:**
- **Rails 8.1 + SQLite3 (Solid Stack):** Already in use; single-node deployment constraint honored
- **Turbo Rails (Turbo Streams):** Next-card swap on `POST /card_reviews` — the Core Value delivery mechanism; no page reload
- **Stimulus Rails:** Card flip (CSS transform toggle), paste import preview — client-only state, no server round-trip
- **Tailwind CSS 4:** 7-day due bar chart implemented as pure CSS height utilities — no charting library
- **Solid Cache:** Due-count nav badge cached per user with 1-hour TTL; invalidated on every card rating
- **Pundit:** DeckPolicy + CardPolicy + CardReviewPolicy; follows existing 21-policy codebase pattern
- **Custom `Flashcards::Sm2Service`:** 30-line pure Ruby class; no `srs`/`repetition` gems (unmaintained, wrong scale)

**No new gems.** `bundle check` should pass with no changes.

### Expected Features

**Must have (table stakes) — v1:**
- Card flip browse mode — fundamental flashcard interaction
- Deck listing (3-tier: official / club / personal) — without scope, no authorization model
- SRS study session (Turbo Stream next-card swap) — Core Value; without this it's a card viewer
- Card CRUD with "저장하고 다음" pattern — can't build a deck without adding cards
- CardReview SRS state persistence — without this, every session starts from zero
- 4-step rating UI (다시/어려움/보통/쉬움) — the SM-2 input surface
- 3 official seed decks — empty-state prevention on first load
- DeckPolicy + CardPolicy (Pundit) — security baseline; cannot ship without
- Due-count nav badge — reason to re-open the app; Solid Cache keeps it cheap
- Empty-state UX + navigation entry point — discoverability for new users

**Should have (differentiators) — v1.x after validation:**
- Statistics: streak, mastery %, 7-day due forecast — meaningful only after CardReview data accumulates
- Paste import — validate single-card form demand first; add bulk input once confirmed
- Club manage onboarding nudge — validate club deck adoption rate first

**Defer (v2+):**
- Card type variants (cloze, objective) — `card_type` enum column reserved but UI deferred
- Public UGC (personal deck sharing) — moderation cost too high for v1
- Email/push notifications — in-app badge sufficient until engagement is proven
- Gamification (leaderboards, badges) — risks incentivizing "快速 넘기기" over genuine learning

### Architecture Approach

The architecture is a clean Rails layered monolith: thin controllers delegating to a service layer (`app/services/flashcards/`), pure query objects (`app/queries/flashcards/`), and Pundit policies with a delegation chain (`CardPolicy` → `DeckPolicy`). No new infrastructure — Solid Cache handles badge caching, the critical `(user_id, next_review_at)` index on `card_reviews` handles due-queue performance, and Turbo Streams handle the real-time next-card swap without any JavaScript routing.

**Major components:**
1. **`Flashcards::Sm2Service`** — Pure Ruby, no ActiveRecord; takes state + rating, returns a Result struct. Tested in isolation without DB.
2. **`Flashcards::SubmitReviewService`** — Upserts `CardReview`, calls `Sm2Service`, busts `DueCountCache`.
3. **`StudyQueueQuery`** — SQL join through `DeckPolicy::Scope`; never loads all cards into Ruby.
4. **`CardReviewsController`** — POST-only; `respond_to format.turbo_stream` replacing `#study-card` frame.
5. **`DeckPolicy::Scope`** — Three-tier resolver: official OR club (approved membership) OR personal (owner).
6. **`Flashcards::DueCountCache`** — Solid Cache wrapper with explicit invalidation; never rely on TTL alone.

### Critical Pitfalls

1. **SM-2 rating scale mismatch** — Map 4-step (1–4) to SM-2 quality (0–5) via `QUALITY_MAP = { 1 => 0, 2 => 2, 3 => 3, 4 => 5 }` and enforce `ease = [1.3, calculated].max`. Unit test all four ratings × fresh/mature card before building anything on top.

2. **Turbo Stream double-submission** — Disable rating buttons immediately on first click (Stimulus); use `find_or_initialize_by` + `update!` server-side for idempotency; rescue `ActiveRecord::RecordNotUnique` as final safety net. Test with simulated slow network in a system spec.

3. **Global study queue (`/study`) leaks club-private cards** — After club membership is revoked, `CardReview` records persist. The queue query MUST join through `DeckPolicy::Scope`, not raw `CardReview` records. Add a request spec: revoke membership → `/study` → verify no club cards.

4. **Streak KST off-by-one** — `Date.today` uses system (UTC) time; `Time.current.to_date` respects `config.time_zone = "Seoul"`. Always use `Time.current` in streak SQL and service code. Unit test at 23:58 KST using `travel_to`.

5. **Fork position chaos** — `Card.dup` copies `position` values; after deletions in the source deck, gaps appear. Renormalize to `1..n` contiguous during fork. Also: `CardReview` records must NOT be copied (ADR 0001). Integration test: verify position sequence is contiguous and CardReview count is zero post-fork.

## Implications for Roadmap

Based on the combined research, a four-phase structure is recommended:

### Phase 1: Foundation — Models, SM-2, Policies
**Rationale:** Everything depends on this. The SM-2 service is the core algorithm; Deck/Card/CardReview are the data model; Pundit policies are the security baseline. Nothing else can be built until these are rock-solid.
**Delivers:** Migrations (decks, cards, card_reviews, tournament_event_decks), SM-2 service + tests, SubmitReviewService, ForkDeckService, DeckPolicy/CardPolicy/CardReviewPolicy, 3 official seed decks.
**Features addressed:** Deck 3-tier model, Card CRUD model, CardReview SRS state, Fork mechanics.
**Pitfalls to avoid:** SM-2 rating mismatch (Phase 1 test gate), Fork position chaos, CardReview policy deck access, Polymorphic owner N+1.
**Research flag:** Standard patterns — no additional research needed.

### Phase 2: Core Study Loop + Card Authoring UI
**Rationale:** The Core Value — SM-2 engine must exist (Phase 1) before the study session can be wired up. Turbo Stream next-card swap is the non-negotiable hot path.
**Delivers:** StudyController, CardReviewsController (Turbo Stream), card flip Stimulus controller, 4-step rating UI, browse mode, card CRUD forms with "저장하고 다음", paste import (Stimulus preview + server parse), due-count badge (Solid Cache), global `/study` queue, navigation entry point.
**Features addressed:** SRS study session, flip browse mode, card CRUD UI, paste import, due-count badge, empty-state UX.
**Pitfalls to avoid:** Double-submission race condition, global queue access leak, paste import separator collision, Pundit 403 in Turbo Stream response (rescue to stream-safe redirect).
**Research flag:** Standard Rails/Hotwire patterns — no additional research needed.

### Phase 3: Statistics
**Rationale:** Streak/mastery/forecast are only meaningful after `CardReview` data accumulates. Structure can be built in Phase 2 but UI completeness deferred here. No new infrastructure — pure SQL aggregations.
**Delivers:** Streak query (SQL group by date, KST-aware), mastery % (SQL count with division-by-zero guard), 7-day due forecast query, `DueForecastQuery`, CSS bar chart, session complete screen.
**Features addressed:** Statistics 4종 (streak, mastery %, 7-day forecast, session summary).
**Pitfalls to avoid:** Streak KST off-by-one, mastery division-by-zero, 7-day forecast loading all CardReviews (use bounded date range query).
**Research flag:** KST midnight boundary logic needs careful testing — may need extra attention during implementation.

### Phase 4: Platform Integration
**Rationale:** Independent of core SRS; can be added once the study loop is validated. Extends existing `TournamentEvent` with a join table. Club nudge is a single conditional banner.
**Delivers:** `TournamentEventDeck` join table + controller + UI on tournament event show page, club manage onboarding nudge (dismissable, 1-time).
**Features addressed:** Tournament event connection, club onboarding nudge, featured toggle.
**Pitfalls to avoid:** TournamentEventDeck cross-club authorization (club manager can only map their own club's decks).
**Research flag:** Standard join table pattern — no additional research needed.

### Phase Ordering Rationale

- **Phase 1 before Phase 2:** SM-2 service and Pundit policies are hard prerequisites for the study loop. Building UI before the algorithm is tested is the root cause of most SRS implementation bugs.
- **Phase 2 before Phase 3:** Statistics require accumulated `CardReview` data; the collection mechanism must exist first.
- **Phase 4 is independent:** `TournamentEventDeck` is a pure join table extension; it doesn't touch the SRS data model and can ship in any order after Phase 1.
- **Seed decks in Phase 1:** Official decks must be present at launch to prevent empty-state trust failures. They belong with the model layer, not the UI layer.

### Research Flags

Phases needing careful implementation attention (not additional pre-research):
- **Phase 1 — SM-2 Service:** Exhaustive unit test gate required before Phase 2 proceeds. All four ratings × fresh/mature card boundary conditions.
- **Phase 3 — Streak/KST:** Timezone boundary is a known trap; `travel_to` test at 23:58 KST is mandatory.

Phases with standard patterns (implementation is straightforward):
- **Phase 2 — Turbo Streams:** Rails 8 + Turbo 8 is well-documented; `turbo_stream.replace` API is stable.
- **Phase 4 — Join table:** Standard Rails join table + nested routes pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Fully constrained by existing Gemfile; verified against `config/importmap.rb` |
| Features | HIGH | Derived directly from PROJECT.md, ADR 0001, and existing model analysis |
| Architecture | HIGH | Follows established patterns from 21 existing Pundit policies and `app/services/` structure |
| Pitfalls | HIGH | SM-2 literature is 35+ years stable; Turbo race conditions are well-documented; ADR 0001 is explicit |

**Overall confidence: HIGH**

### Gaps to Address

- **`card_type` enum future shape:** Reserved `basic=0` with intent to add `cloze`, `objective` in v2. The exact UI contract for those types is unspecified — keep the enum column, do not build UI scaffolding.
- **ActiveStorage images (`front_image`/`back_image`):** Schema declarations are planned but UI is hidden behind a feature condition until S3 is configured. Ensure form params never expose these fields accidentally (security — verify with a request spec).
- **Mastery threshold definition:** Research assumes `interval_days >= 21` = "mastered." This is a product decision, not a technical one. Confirm with the product owner before implementing the statistic; a wrong threshold is a user-facing lie.

## Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md` — requirements, Out of Scope, Key Decisions
- `docs/adr/0001-flashcard-cardreview-shared-cards.md` — Card sharing model (fork behavior)
- Existing `Gemfile` + `config/importmap.rb` — confirmed stack constraints
- SM-2 algorithm: Piotr Woźniak's 1987 specification (public domain, 35+ years stable)
- Rails 8.1 Turbo Streams API: official Turbo documentation

### Secondary (MEDIUM confidence)
- Existing `app/services/`, `app/policies/` patterns — inferred from 21 policy files and service examples
- `app/models/club_membership.rb`, `app/models/tournament_event.rb` — integration surface confirmed

### Tertiary (LOW confidence — validate during implementation)
- Mastery threshold (`interval_days >= 21`) — industry convention, not verified against product requirement
- ActiveStorage S3 readiness — assumed not configured for production; verify before enabling image UI

---
*Research completed: 2026-05-29*
*Ready for roadmap: yes*
