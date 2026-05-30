---
phase: "03-srs-learning-loop"
plan: "05"
subsystem: "flashcards"
tags: [gap-closure, security, idor, turbo-stream, view-cta]
dependency_graph:
  requires: [03-02, 03-04]
  provides: [STUDY-01-entry, BROWSE-01, CR-01-closure, CR-02-closure, WR-01-closure]
  affects: [app/views/decks/show.html.erb, app/controllers/card_reviews_controller.rb]
tech_stack:
  added: []
  patterns: [turbo_stream.replace inline render, IDOR-hardened controller, disabled HTML button ARIA]
key_files:
  created: []
  modified:
    - app/views/decks/show.html.erb
    - app/controllers/card_reviews_controller.rb
    - spec/requests/decks/studies_spec.rb
    - spec/requests/decks/browses_spec.rb
    - spec/requests/card_reviews_spec.rb
decisions:
  - "Derive @deck unconditionally from @card.deck (never params[:deck_id]) to close IDOR"
  - "Use inline turbo_stream.replace render on both error branches to eliminate MissingTemplate risk"
  - "Disabled HTML <button> (not <a>) for empty-deck guard — enforces disabled at HTML/ARIA level"
  - "WR-02..WR-05 and IN-01..IN-02 remain deferred to Phase 4 cleanup per scope discipline"
metrics:
  duration_minutes: 30
  completed_date: "2026-05-30"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 5
---

# Phase 03 Plan 05: Gap Closure (BROWSE-01 + STUDY-01 + CR-01/CR-02) Summary

Phase 3 검증 갭(BROWSE-01 FAILED, STUDY-01 PARTIAL)과 코드 리뷰 결함 2종(CR-01 IDOR, CR-02 MissingTemplate)을 TDD Red→Green 사이클로 완전 해소했다.

## What Was Built

### Task 1: Deck Show 학습/훑어보기 진입점 (STUDY-01 + BROWSE-01)

`app/views/decks/show.html.erb`에 `.deck-actions` CTA 영역 추가:
- 카드 ≥1: `link_to "학습 시작"` → `deck_study_path(@deck)` + `link_to "훑어보기"` → `deck_browse_path(@deck)`
- 카드 0: disabled `<button aria-disabled="true" title="카드를 먼저 추가하세요">` + hint span (ROADMAP SC#5)

### Task 2: CR-01 IDOR + CR-02 MissingTemplate 수정

`app/controllers/card_reviews_controller.rb` 리라이트:
- CR-01: `if params[:deck_id].present?` 조건부 블록 제거 → `@deck = @card.deck` + `authorize @deck, :show?` 무조건 실행
- CR-02: `render :error` → `render turbo_stream: turbo_stream.replace("study-card", partial: "card_reviews/error")` (양쪽 에러 분기)
- WR-01: `flash.now[:alert]` 데드코드 삭제
- WR-04: 미사용 `card_review_params` private 메서드 삭제
- `@next_card` 조회: `@deck ? ... : nil` 삼항 제거 (이제 항상 non-nil)

## Verification Truths Flipped

| Truth | Before | After |
|-------|--------|-------|
| STUDY-01 entry point (GET /decks/:id → 학습 시작 CTA) | PARTIAL | VERIFIED |
| BROWSE-01 (GET /decks/:id → 훑어보기 링크) | FAILED | VERIFIED |

## Code Review Findings Flipped

| Finding | Severity | Before | After |
|---------|----------|--------|-------|
| CR-01 IDOR (deck authorized via params[:deck_id]) | Critical | Open | Resolved |
| CR-02 MissingTemplate (render :error on ArgumentError) | Critical | Open | Resolved |
| WR-01 flash.now[:alert] dead code | Warning | Open | Resolved |
| WR-04 card_review_params unused method | Warning | Open | Resolved |

## Deliberately Deferred (Phase 4)

WR-02, WR-03, WR-05, IN-01, IN-02 — 이번 gap closure 범위 밖. Phase 4 cleanup으로 명시 이월.

## Test Results

```
bundle exec rspec spec/requests/card_reviews_spec.rb spec/requests/decks/studies_spec.rb spec/requests/decks/browses_spec.rb spec/requests/study_spec.rb spec/services/flashcards/submit_review_service_spec.rb spec/queries/flashcards/global_study_queue_query_spec.rb

✓ RSpec: 58 passed (0.93s)
```

New specs added: 7 (4 entry-point specs across studies/browses + 3 card_reviews IDOR/regression/CR-02 specs).

## Linter Results

```
bundle exec rubocop app/controllers/card_reviews_controller.rb spec/requests/card_reviews_spec.rb spec/requests/decks/studies_spec.rb spec/requests/decks/browses_spec.rb

✓ rubocop (4 files) — 0 offenses

Note: app/views/decks/show.html.erb reports Lint/Syntax false positive from Rubocop's
ERB parser (unexpected token tLT on line 1). This is a pre-existing false positive
for ERB files and was not introduced by this plan's changes.
```

## Brakeman Results

```
bin/brakeman --no-pager
Security Warnings: 3
```

3 warnings are all in `app/services/admin/database_backups/create_service.rb`, `app/controllers/admin/users_controller.rb`, and `app/controllers/admin/data_management_controller.rb`. None in files touched by this plan. The IDOR fix removed a security vulnerability — no new warnings introduced.

## Commits

| Task | Phase | Hash | Message |
|------|-------|------|---------|
| Task 1 | RED | db2f10e | test(03-05): add failing specs for deck show study/browse entry points |
| Task 1 | GREEN | fdc8b17 | feat(03-05): add study/browse CTAs to deck show with empty-deck guard |
| Task 2 | RED | c118026 | test(03-05): add IDOR closure + strict 422 specs for card_reviews |
| Task 2 | GREEN | 45c9114 | fix(03-05): close CR-01 IDOR and CR-02 MissingTemplate; remove WR-01 dead code |

## Deviations from Plan

None — plan executed exactly as written.

## TDD Gate Compliance

- Task 1: `test(...)` RED commit (db2f10e) → `feat(...)` GREEN commit (fdc8b17) ✓
- Task 2: `test(...)` RED commit (c118026) → `fix(...)` GREEN commit (45c9114) ✓

## Known Stubs

None — all CTAs point to real routes, controller derives real deck from card.

## Self-Check: PASSED

All key files exist:
- FOUND: app/views/decks/show.html.erb
- FOUND: app/controllers/card_reviews_controller.rb
- FOUND: spec/requests/decks/studies_spec.rb
- FOUND: spec/requests/decks/browses_spec.rb
- FOUND: spec/requests/card_reviews_spec.rb
- FOUND: .planning/phases/03-srs-learning-loop/03-05-SUMMARY.md

All commits present:
- FOUND: db2f10e (Task 1 RED)
- FOUND: fdc8b17 (Task 1 GREEN)
- FOUND: c118026 (Task 2 RED)
- FOUND: 45c9114 (Task 2 GREEN)
