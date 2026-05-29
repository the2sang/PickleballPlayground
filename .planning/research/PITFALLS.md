# Pitfalls Research

**Domain:** SRS (Spaced Repetition System) Flashcard App — Rails 8, Hotwire, SQLite, Pundit
**Researched:** 2026-05-29
**Confidence:** HIGH (domain-specific; drawn from SM-2 algorithm literature, Rails Turbo Stream patterns, and project-specific ADR decisions)

---

## Critical Pitfalls

### Pitfall 1: SM-2 Algorithm — Rating Scale Mismatch

**What goes wrong:**
The canonical SM-2 algorithm uses a 0–5 quality scale. This project uses a 4-step (1–4) scale. If you implement the SM-2 formula verbatim (`EF' = EF + (0.1 - (5-q)*(0.08 + (5-q)*0.02))`), the ease factor will decay incorrectly because the formula assumes ratings from 0 (blackout) to 5 (perfect). The locked Phase 1 quality mapping is `다시=1, 어려움=3, 보통=4, 쉬움=5` (per user decision during Phase 1 planning). Earlier drafts mapped 다시→0 / 어려움→2; those values put 어려움 on the lapse side of the cutoff (q<3), collapsing legitimate progress on hard cards into a daily repetition loop that never resolves.

**Why it happens:**
Developers copy the formula from Wikipedia/SuperMemo documentation without adapting it to the project's rating scale.

**How to avoid:**
Define `QUALITY_MAP = { 1 => 1, 2 => 3, 3 => 4, 4 => 5 }.freeze` in `Flashcards::Sm2Service` (다시=1, 어려움=3, 보통=4, 쉬움=5 — per user decision during Phase 1 planning; locked in `Sm2Service::QUALITY_MAP`) and translate before applying the formula. Also enforce `ease = [1.3, calculated_ease].max` explicitly. Write unit tests for all four rating values with a fresh card (repetitions=0) and a mature card (interval=21+) to catch boundary violations before shipping.

**Warning signs:**
Cards rated "어려움" every time don't recover after 7+ days. Cards rated "쉬움" accumulate interval longer than 6 months. EF values appear as negative or > 4.0 in the database.

**Phase to address:** Phase 1 (SM-2 Service implementation) — must be tested exhaustively before the study loop is built on top of it.

---

### Pitfall 2: Turbo Stream Race Condition — Double Card Rating

**What goes wrong:**
The study loop's core cycle is `POST /card_reviews` → Turbo Stream swaps in the next card. If the user clicks a rating button twice before the stream response arrives (slow connection, click-happy users), two `POST` requests fire. The second hits with a duplicate `(user_id, card_id)` — the DB unique index raises `ActiveRecord::RecordNotUnique`. If this exception bubbles unhandled, the user sees a 500 page mid-session — Core Value destroyed.

**Why it happens:**
No button-disabling after the first click, and no server-side idempotency guard. Common oversight when Turbo Stream feels "instant" in development over localhost.

**How to avoid:**
1. Stimulus controller: disable all rating buttons immediately on first click, re-enable only if the stream response fails.
2. Server-side: `CardReview.find_or_initialize_by(user_id:, card_id:)` + `update!` instead of `create!`. Never raise on duplicate key — update the existing record.
3. Add `rescue ActiveRecord::RecordNotUnique` in the controller as a final safety net, return the next card stream anyway.

**Warning signs:**
Any `ActiveRecord::RecordNotUnique` in production logs. Users reporting skipped cards. Rating button stays active during pending requests.

**Phase to address:** Phase 2 (Study loop + Turbo Stream). Write a system test with simulated slow network (Capybara delay) to reproduce.

---

### Pitfall 3: Global Study Queue (`/study`) Leaks Club-Private Cards

**What goes wrong:**
`/study` aggregates due cards across all decks a user can access. If the query is `CardReview.where(user: current_user).due.includes(:card => :deck)` without re-checking deck-level access, a user who was removed from a club between sessions still sees club deck cards in their global queue. The `CardReview` record persists even after `ClubMembership` is revoked.

**Why it happens:**
The SRS state (`CardReview`) outlives the authorization context. Developers assume that because the user had access when they started studying, the CardReview will always be valid.

**How to avoid:**
The global study queue query must join through `Deck` and re-apply `DeckPolicy::Scope`. Use a scope like `CardReview.joins(:card => :deck).merge(DeckPolicy::Scope.new(current_user, Deck).resolve)`. Do not build the queue from raw CardReview records.

**Warning signs:**
Brakeman silent on this (it's a logic error, not a static issue). Test by: (1) join club, (2) start studying club deck, (3) revoke membership, (4) visit `/study` — verify no club cards appear.

**Phase to address:** Phase 2 (Study routes + Pundit scopes). Add a request spec that covers this scenario.

---

### Pitfall 4: Polymorphic `owner` on Deck — N+1 on Deck Index

**What goes wrong:**
`Deck` has a polymorphic `owner` (nil for official, Club for club decks, User for personal). The `/decks` hub lists decks grouped by scope. Without eager loading, Rails fires one query per deck to resolve the polymorphic `owner`, causing N+1 that gets worse as the user's accessible deck count grows. Polymorphic eager loading requires `includes(:owner)` AND correct handling when `owner_type` is nil (official decks).

**Why it happens:**
`includes(:owner)` on polymorphic works only when all records have a non-nil `owner_type`. When `owner` is nil for official decks, ActiveRecord may still fire extra queries or raise `nil` association errors in views.

**How to avoid:**
Query decks in scope-separated groups: one query for official (no owner load needed), one for club (eager `includes(:owner)`), one for personal (owner = current_user, no load needed). Alternatively use `preload` instead of `includes` to guarantee separate queries without Rails' automatic join logic interfering with nil polymorphics.

**Warning signs:**
Rails development logs show 10+ `SELECT * FROM clubs WHERE id = ?` lines when loading `/decks`. Slow index page as deck count grows.

**Phase to address:** Phase 1 (Deck model + index view). Add Bullet gem in development only to catch N+1 before it ships.

---

### Pitfall 5: Streak Calculation Off-by-One at KST Midnight

**What goes wrong:**
Streak counts consecutive days with at least one completed card review. The project hardcodes KST (`config.time_zone = "Seoul"`). If the streak query uses `Date.today` (Ruby's system time, possibly UTC in production) instead of `Time.current.in_time_zone('Seoul').to_date`, a user who studies at 11:58 PM KST gets credited to "yesterday" UTC — breaking their streak the next calendar day even though they studied.

**Why it happens:**
Rails stores timestamps in UTC in the database. `Date.today` in Ruby is the server's local date, not necessarily KST. Even with `config.time_zone = "Seoul"`, `Date.today` does not respect Rails' configured timezone — only `Time.current.to_date` does.

**How to avoid:**
Always use `Time.current.to_date` (which respects `config.time_zone`) for streak calculations. In streak SQL queries, convert UTC timestamps to KST before grouping by date: `DATE(last_reviewed_at AT TIME ZONE 'Asia/Seoul')` or handle the conversion in Ruby after fetching. Write a model spec that simulates a review at 11:58 PM KST and verifies the streak is credited to KST date.

**Warning signs:**
Streak resets for users who study late at night. `Date.today` anywhere in streak-related service code.

**Phase to address:** Phase 3 (Statistics). Catch with a unit test setting `Time.current` to 23:58 KST.

---

### Pitfall 6: Paste Import — Separator Collision Destroys Card Content

**What goes wrong:**
Paste import uses configurable separators (card/face). If a user's content contains the default separator (e.g., a tab `\t` for face separator), the parse splits a card face in two, silently creating malformed cards. The preview step exists to catch this — but only if the UI makes the collision obvious. If the preview just shows a truncated card without warning, users click "일괄 저장" and corrupt their deck.

**Why it happens:**
Text pasted from formatted documents (Excel, web pages) often contains tabs. The preview renders partial content and users assume it's correct.

**How to avoid:**
In the server-side parser, detect if the chosen separator appears more times per line than expected (more than 2 face parts per card) and return a validation error with the offending line highlighted. In the preview, render a warning banner: "카드 [N]번: 구분자가 내용에 포함되어 있습니다." Do not silently save malformed cards.

**Warning signs:**
Cards with blank `back` or multi-fragment `front`. User support reports of "내 카드가 이상하게 저장됐어요."

**Phase to address:** Phase 2 (Card authoring UX). Parser must have unit tests with adversarial inputs (tab-in-content, empty lines, whitespace-only cards).

---

### Pitfall 7: Fork Copies Cards Without Resetting `position` — Ordering Chaos

**What goes wrong:**
Fork creates a personal deck by copying cards from the source deck. If `position` values are copied as-is (e.g., `[1, 2, 3]`), and the user later adds new cards to their forked deck, the new cards get position `0` (default) or `nil`, breaking ordering. Alternatively, if the fork uses `Card.dup` and the source deck has gaps in positions (1, 3, 5 after deletions), the forked deck inherits those gaps.

**Why it happens:**
`Card.dup` copies all attributes including `position`. Developers forget that `position` is relative to the deck and must be renormalized on fork.

**How to avoid:**
When forking, iterate source cards in position order and assign sequential positions starting at 1: `source_deck.cards.ordered.each_with_index { |c, i| new_card = c.dup; new_card.position = i + 1; ... }`. Do not copy `id` or `created_at`. Explicitly confirm `CardReview` records are NOT copied (per ADR 0001).

**Warning signs:**
Forked decks showing cards in wrong order. `position` NULL values in forked cards. Flip browse showing random card order.

**Phase to address:** Phase 1 (Fork mechanics). Fork service needs an integration test that verifies position sequence is `1..n` contiguous after fork.

---

### Pitfall 8: Pundit `CardPolicy` — Implicit Trust in `DeckPolicy` Delegation Can Be Bypassed

**What goes wrong:**
`CardPolicy` delegates to `DeckPolicy`. But `POST /card_reviews` for SRS creates/updates a `CardReview` — not a `Card`. If `CardReviewPolicy` only checks `record.user == current_user` and doesn't verify the user still has access to the card's parent deck, a user can POST a rating for a card they can no longer access (e.g., club removed). This is a data integrity issue, not an auth bypass — but it means CardReview records accumulate for inaccessible cards.

**Why it happens:**
`CardReviewPolicy` is a simpler check than `CardPolicy`, and developers stop at `record.user == current_user` assuming it's sufficient.

**How to avoid:**
`CardReviewPolicy#create?` should also verify: `DeckPolicy.new(user, record.card.deck).show?`. Add a `before_action :verify_card_accessible` to the `CardReviewsController` that loads the card and its deck, then calls `authorize @card.deck, :show?`.

**Warning signs:**
`CardReview` records where `card.deck.scope == 'club'` but user has no active `ClubMembership` for that club.

**Phase to address:** Phase 1 (Pundit policies). Add a request spec: revoke membership, attempt `POST /card_reviews` with a club card — expect 403.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Tags as comma-separated string | No join table, simple migration | Can't query by tag efficiently, no tag normalization | Acceptable for v1 — add `taggings` table only when tag-based filtering is a validated requirement |
| KST hardcoded for streak | No per-user timezone complexity | Breaks for overseas users, requires migration to `user.timezone` later | Acceptable for v1 Korean-only community |
| SM-2 implemented inline in service | Fast to build | If algorithm needs A/B testing or per-deck tuning, service must be refactored | Acceptable for v1 — isolate in `Sm2Algorithm` value object to minimize future extraction cost |
| ActiveStorage structure without S3 | Schema ready for images | UI complexity if "hidden" fields leak through form serialization or JS | Never hide fields via CSS alone — use conditional `if feature_enabled?(:card_images)` wrapper |
| `interval_days` integer (not float) | Simpler queries, readable schema | SM-2 computes fractional intervals in some implementations — rounding to integer loses precision on early-interval cards | Acceptable — SM-2 standard rounds to integer days; document this as intentional |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Turbo Stream + `POST /card_reviews` | Return a full page redirect on validation error — destroys study session | Return `422 Unprocessable Entity` with a Turbo Stream error frame, never redirect mid-session |
| Solid Cache + due badge count | Cache key `"due_count/#{user.id}"` without TTL awareness — stale badge after cache warmup | Use `Rails.cache.fetch("due_count/#{user.id}", expires_in: 1.hour)` AND call `Rails.cache.delete("due_count/#{user.id}")` after any card rating or deck change |
| Pundit + Turbo Stream | `authorize` raises `Pundit::NotAuthorizedError` during a stream response — Rails renders 403 HTML inside a stream, breaking the DOM | Rescue `Pundit::NotAuthorizedError` in `ApplicationController` with a stream-safe redirect: `render turbo_stream: turbo_stream.action(:redirect, root_path)` |
| ClubMembership status check | `current_user.clubs.include?(club)` — ignores `status: :approved` | Always query `ClubMembership.where(user: current_user, club: club, status: :approved)` explicitly |
| TournamentEventDeck position | Rely on insertion order for display — breaks when records are deleted and reinserted | Always `ORDER BY position` explicitly; never rely on `id` or insertion order for display sequence |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Missing `(user_id, next_review_at)` index on `card_reviews` | `/study` page slow — full table scan to find due cards | Required by spec — add in migration, verify with `EXPLAIN QUERY PLAN` | ~1,000 reviews per user (a power user with 5 decks × 50 cards) |
| Global study queue joins without limit | `/study` returns all due cards at once, rendered in DOM | Limit queue to 20 cards per session; paginate or stream next card only | 100+ due cards accumulates during a multi-day absence |
| Mastery % calculated in Ruby | `deck.cards.each { ... }` — loads all cards into memory | Calculate as SQL: `cards.where('interval_days >= 21').count.to_f / cards.count` | >200 cards per deck |
| 7-day due forecast loads all CardReviews | N+1 per day of forecast | Single query grouping by `DATE(next_review_at)` with `WHERE next_review_at BETWEEN ? AND ?` | Any user with > 500 total reviews |
| Streak query iterates dates in Ruby | Ruby loop from today backwards until gap found | SQL: `GROUP BY date, COUNT(*)` then find max consecutive run in Ruby from the result set (not N queries) | Streak > 30 days |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `Deck.find(params[:id])` without scope check before `authorize` | Timing oracle: 404 for inaccessible deck vs. 403 leaks deck existence | `authorize` first (Pundit finds the record), or use `policy_scope` to constrain the query before find |
| Paste import textarea content rendered unescaped in preview | XSS — malicious card content executes in other users' browsers if club decks are shared | Always use `ERB::Util.html_escape` / Rails' auto-escaping; never use `html_safe` on user-provided card text |
| `forked_from_deck_id` not validated on fork | User can POST `forked_from_deck_id` pointing to a private deck they don't own | Validate: `authorize Deck.find(params[:forked_from_deck_id]), :fork?` before creating the personal deck |
| CardReview rating param not validated to `[1,2,3,4]` | Unexpected SM-2 output for out-of-range values; potential exploit if quality is used in raw SQL | Validate `params[:rating].to_i.in?([1,2,3,4])` and raise `ActionController::BadRequest` otherwise |
| `owner_id` / `owner_type` accepted from form params | Mass-assignment of polymorphic owner — user could claim a deck as club-owned | Never permit `owner_id`, `owner_type` from form params; set in controller based on `scope` param and current_user context |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| "저장하고 다음" submits full form on Enter | If `textarea` is focused (hint field), Enter adds a newline — user thinks card was saved but it wasn't | Use `Ctrl+Enter` / `Cmd+Enter` for save; or ensure focus management moves to a non-textarea field after front/back entry |
| SRS session ends without summary screen | User doesn't know they finished — thinks the app is broken | After last card rated, Turbo Stream renders a "세션 완료" screen with stats (cards reviewed, time spent) |
| Flip browse doesn't distinguish from SRS | User flips through cards thinking it counts as review — no CardReview created | Clear visual differentiation: "훑어보기" mode has a distinct banner, no rating buttons, explicit label "진도 미기록" |
| Due badge count stale for 1 hour | User studies 10 cards, badge still shows 10 — confusing | Invalidate cache on every `POST /card_reviews` response (in controller, not callback — explicit is better) |
| Empty deck study link is clickable | Clicking "학습 시작" on a 0-card deck drops into an empty session — confusing | Disable/hide the study button and show "카드를 먼저 추가하세요" when `deck.cards.none?` |

---

## "Looks Done But Isn't" Checklist

- [ ] **SM-2 Service:** Rating scale mapped from 4-step to 0–5 before formula application — verify with unit test for all four ratings
- [ ] **Study Loop:** Double-submission guard on rating buttons (Stimulus disable + server idempotency) — verify with slow-network system test
- [ ] **Global Queue (`/study`):** Pundit scope applied to deck access check — verify with membership-revoked request spec
- [ ] **Streak:** Uses `Time.current.to_date` (not `Date.today`) — verify with a time-travel spec at 23:58 KST
- [ ] **Fork:** CardReview records NOT copied — verify post-fork `CardReview.where(user: new_user, card_id: forked_cards.ids)` is empty
- [ ] **Fork:** Position sequence is `1..n` contiguous — verify with integration test
- [ ] **Paste Import:** Parser rejects/warns on separator collision — verify with adversarial input unit test
- [ ] **ActiveStorage fields:** Hidden, not just visually — verify no `front_image_attachment` field appears in form params
- [ ] **Due Badge Cache:** Invalidated on rating AND on card add/remove — verify cache is empty after each mutation
- [ ] **TournamentEventDeck auth:** Club manager can only map decks from their own club (not other clubs' decks) — verify with request spec
- [ ] **Mastery %:** Division-by-zero guard when `deck.cards.count == 0` — verify with empty deck spec
- [ ] **7-day Forecast:** Query scoped to accessible decks, not all user's CardReviews — verify with club membership revocation

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| SM-2 formula wrong (discovered after launch) | HIGH | Recalculate all `CardReview` records in a migration using corrected formula; write migration that re-runs `Sm2Service.call` on all existing reviews with their `last_rating`; users will see changed schedules |
| Club card data leak in global queue | MEDIUM | Deploy fix immediately; no data breach (users see cards, not PII); audit `CardReview` records for access violations; notify affected users |
| Streak off-by-one due to UTC/KST | LOW | Deploy fix; reset affected users' streaks to correct value via `bin/rails runner`; send in-app notice |
| Paste import created corrupt cards | MEDIUM | Identify affected cards via `Card.where("back IS NULL OR back = ''")` in affected decks; notify deck owners; provide bulk-delete tool |
| Double-submission created duplicate reviews | LOW | `CardReview` unique index prevents at DB level; clean up any partial state with a script if controller raised before responding |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| SM-2 rating scale mismatch | Phase 1 — SM-2 Service | Unit test: all 4 ratings × fresh/mature card |
| Turbo Stream double-submission | Phase 2 — Study Loop | System test: double-click rating button |
| Global queue deck access leak | Phase 2 — Study Routes + Pundit | Request spec: revoked membership, `/study` |
| Polymorphic owner N+1 | Phase 1 — Deck model + index | Bullet gem in dev; request spec with 10 decks |
| Streak KST off-by-one | Phase 3 — Statistics | Unit test: `travel_to` 23:58 KST |
| Paste import separator collision | Phase 2 — Card authoring | Unit test: adversarial paste content |
| Fork position chaos | Phase 1 — Fork service | Integration test: position sequence post-fork |
| CardReview policy deck access | Phase 1 — Pundit policies | Request spec: POST /card_reviews after club removal |
| Mastery division-by-zero | Phase 3 — Statistics | Unit test: empty deck |
| XSS in card preview | Phase 2 — Paste import UI | Security test: `<script>alert(1)</script>` in front field |
| Cache stale due badge | Phase 3 — Notifications | Integration test: study card, verify badge count drops |
| TournamentEventDeck cross-club mapping | Phase 4 — Tournament integration | Request spec: club_manager maps another club's deck |

---

## Sources

- SM-2 algorithm specification: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
- Rails Turbo Streams idempotency patterns: community convention (race condition is well-known in Hotwire Discord)
- ADR 0001: `docs/adr/0001-flashcard-cardreview-shared-cards.md` (project-specific)
- Pundit polymorphic scope patterns: Pundit README + project's 21 existing policy files
- Rails timezone pitfall (`Date.today` vs `Time.current`): Rails Guides — Time Zones section
- SQLite EXPLAIN QUERY PLAN: SQLite documentation for index verification
- Brakeman false-negative on logic-level auth: Brakeman documentation (static analysis scope limitations)

---
*Pitfalls research for: 낱말카드 (Flashcards) v1 — SRS system on Rails 8 + Hotwire + SQLite*
*Researched: 2026-05-29*
