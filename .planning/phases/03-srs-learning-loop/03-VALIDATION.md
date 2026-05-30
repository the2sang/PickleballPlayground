---
phase: 3
slug: srs-learning-loop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | RSpec (Minitest 없음, RSpec 전용) |
| **Config file** | spec/spec_helper.rb, spec/rails_helper.rb |
| **Quick run command** | `bundle exec rspec spec/requests/` |
| **Full suite command** | `bundle exec rspec` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bundle exec rspec spec/requests/ spec/services/ spec/queries/`
- **After each wave:** Run `bundle exec rspec` (full suite)
- **Before verification:** Run `bundle exec rspec && bin/brakeman --no-pager`

---

## Validation Architecture

See 03-RESEARCH.md §Validation Architecture for full details.

Key checkpoints:
1. **CardReviewsController** — POST /card_reviews returns turbo_stream; idempotency (double-submit = 1 DB row)
2. **SubmitReviewService** — SM-2 호출 결과 DB 검증 (quality 매핑 {1=>1, 2=>3, 3=>4, 4=>5})
3. **StudyQueueQuery** — due + new limit; personal + official only (policy_scope 금지)
4. **Stimulus study_session_controller** — flip 동작, 버튼 disable, 키보드 1/2/3/4
5. **Browse mode** — CardReview 미생성, client-side only
6. **brakeman** — 신규 경고 0

---

## Coverage Requirements

| Layer | Required Specs | Target |
|-------|---------------|--------|
| Request | studies_spec, card_reviews_spec, study_spec (global) | 100% happy path + error |
| Service | submit_review_service_spec | SM-2 매핑 검증 |
| Query | study_queue_query_spec | due/new 경계값 |
| System | study_session_spec, browse_mode_spec | Capybara E2E |
