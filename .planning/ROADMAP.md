# Roadmap: 낱말카드 (Flashcards) v1

## Overview

Foundation first: data models, the SM-2 algorithm service, and Pundit policies establish the secure substrate everything builds on. Deck and card management UI ships next so users can actually populate decks. The study session (Core Value — Turbo Stream next-card swap) follows once the data layer is solid. Advanced features (paste import, fork, statistics) extend the learning experience. Finally, tournament integration connects flashcards to the broader platform.

## Phases

- [ ] **Phase 1: Foundation** - Models, SM-2 algorithm service, Pundit policies, security baseline
- [ ] **Phase 2: Deck & Card Management** - Deck/card CRUD UI, navigation, seed decks, due-count badge
- [ ] **Phase 3: Study Session** - SRS study loop (Turbo Stream), flip browse mode
- [ ] **Phase 4: Advanced Features** - Paste import, deck fork, learning statistics
- [ ] **Phase 5: Tournament Integration** - Link decks to tournament events

## Phase Details

### Phase 1: Foundation
**Goal**: Secure, tested data layer exists — models, SM-2 service, and authorization policies are ready for UI to build on
**Depends on**: Nothing (first phase)
**Requirements**: MODEL-01, MODEL-02, MODEL-03, MODEL-04, MODEL-05, MODEL-06, MODEL-07, SM2-01, SM2-02, SM2-03, SM2-04, SM2-05, SM2-06, AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, TEST-04, TEST-05, SEC-01, SEC-02, SEC-03, SEC-04
**Success Criteria** (what must be TRUE):
  1. `bin/rails db:migrate` creates decks, cards, card_reviews, and tournament_event_decks tables with correct columns, constraints, and the `(user_id, next_review_at)` composite index
  2. `Flashcards::Sm2Service` correctly computes `ease`, `interval_days`, `repetitions`, and `next_review_at` for all four rating inputs — unit tests pass green
  3. A user attempting to read or modify another user's CardReview raises `Pundit::NotAuthorizedError`
  4. `bin/brakeman --no-pager` reports 0 new warnings
  5. `bundle exec rspec spec/models/ spec/services/ spec/policies/` passes with no failures
**Plans**: TBD

### Phase 2: Deck & Card Management
**Goal**: Users can create, browse, and manage decks and cards; official seed decks and navigation entry point exist
**Depends on**: Phase 1
**Requirements**: DECK-01, DECK-02, DECK-03, DECK-04, DECK-05, DECK-06, DECK-07, DECK-08, DECK-09, CARD-01, CARD-02, CARD-03, CARD-04, CARD-06, HUB-01, HUB-02, HUB-03, NAV-01, NAV-02, NAV-03, NAV-04, SEED-01, SEED-02, TEST-02
**Success Criteria** (what must be TRUE):
  1. A site_admin can create an official deck, add cards, and other authenticated users can view it at `/decks`
  2. An approved club member can create a club deck; non-members cannot see it in `/decks`
  3. The utility dropdown shows a "낱말카드" link with a due-count badge (cached, invalidated on change)
  4. `/decks` groups decks by official/club/personal and shows the "오늘의 복습" hero with due count
  5. `bin/rails db:seed` creates the 3 official seed decks idempotently (re-run produces no duplicates)
**Plans**: TBD
**UI hint**: yes

### Phase 3: Study Session
**Goal**: The Core Value is delivered — users can study due cards with SM-2 rating and see the next card instantly via Turbo Stream
**Depends on**: Phase 2
**Requirements**: STUDY-01, STUDY-02, STUDY-03, STUDY-04, STUDY-05, STUDY-06, STUDY-07, BROWSE-01, BROWSE-02, BROWSE-03, BROWSE-04, BROWSE-05, TEST-01, TEST-03
**Success Criteria** (what must be TRUE):
  1. A user at `/decks/:id/study` rates a card with one of the four buttons (다시/어려움/보통/쉬움) and the next due card appears without a page reload
  2. A user at `/study` sees a unified queue of all due cards across accessible decks; club-private cards from revoked memberships do not appear
  3. Rating the last card in a session displays the "오늘 학습 완료" completion screen
  4. New cards (no CardReview record) appear in the due queue
  5. Flip browse mode lets a user flip and navigate cards without creating any CardReview records
**Plans**: TBD
**UI hint**: yes

### Phase 4: Advanced Features
**Goal**: Users can bulk-import cards via paste, fork decks into personal copies, and track learning progress with statistics
**Depends on**: Phase 3
**Requirements**: CARD-05, FORK-01, FORK-02, FORK-03, STAT-01, STAT-02, STAT-03, STAT-04
**Success Criteria** (what must be TRUE):
  1. A user can paste multi-card text into a textarea, specify separators, preview parsed cards, and save them all in one action
  2. Forking an official or club deck creates a personal deck with the same cards but zero CardReview records (ADR 0001)
  3. `/decks` displays the user's current streak (consecutive KST study days) and a 7-day due forecast CSS bar chart
  4. A deck's show page displays mastery % (cards with `interval_days >= 21`)
**Plans**: TBD
**UI hint**: yes

### Phase 5: Tournament Integration
**Goal**: Tournament events can be linked to flashcard decks; attendees see study material on the event page
**Depends on**: Phase 1
**Requirements**: TOURN-01, TOURN-02, TOURN-03
**Success Criteria** (what must be TRUE):
  1. A club manager can map official decks and their own club's decks to a tournament event via `tournament_events/:id/edit`
  2. A club manager cannot map decks from other clubs to an event
  3. When at least one deck is linked, `tournament_events/:id` shows an "이 종목 학습하기" card at the top
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5
(Phase 5 depends only on Phase 1, so it can execute in parallel with Phases 2–4 if needed)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/TBD | Not started | - |
| 2. Deck & Card Management | 0/TBD | Not started | - |
| 3. Study Session | 0/TBD | Not started | - |
| 4. Advanced Features | 0/TBD | Not started | - |
| 5. Tournament Integration | 0/TBD | Not started | - |
