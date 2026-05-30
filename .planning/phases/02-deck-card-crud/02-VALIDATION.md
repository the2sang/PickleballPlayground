---
phase: 02
slug: deck-card-crud
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | RSpec ~7.x |
| **Config file** | `spec/spec_helper.rb`, `spec/rails_helper.rb` |
| **Quick run command** | `bundle exec rspec spec/requests/decks_spec.rb spec/services/flashcards/paste_import_service_spec.rb --fail-fast` |
| **Full suite command** | `bundle exec rspec` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bundle exec rspec spec/requests/decks_spec.rb --fail-fast`
- **After every plan wave:** Run `bundle exec rspec spec/requests/ spec/services/ --fail-fast`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-W0-01 | W0 | 0 | TEST-02 | — | N/A | setup | `mkdir -p spec/system spec/requests/cards spec/services/flashcards` | ❌ W0 | ⬜ pending |
| 02-W0-02 | W0 | 0 | TEST-02 | — | N/A | setup | `bundle exec rspec spec/support/` | ❌ W0 | ⬜ pending |
| 02-01-01 | 01 | 1 | DECK-01 | T-02-01 | POST /decks 401 if unauthenticated | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | DECK-02 | T-02-01 | PATCH /decks/:id 403 if not owner | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | DECK-03 | T-02-01 | DELETE /decks/:id cascade + 403 non-owner | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | DECK-04 | — | GET /decks renders 3 sections | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | DECK-06 | — | club section only if approved member | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 1 | DECK-07 | — | empty state hero renders for new user | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-01-07 | 01 | 1 | DECK-09 | — | nav contains 낱말카드 link | request | `bundle exec rspec spec/requests/decks_spec.rb` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | CARD-01 | T-02-02 | POST /decks/:id/cards 401 unauthenticated | request | `bundle exec rspec spec/requests/cards_spec.rb` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 1 | CARD-04 | T-02-02 | DELETE /decks/:id/cards/:id 403 non-owner | request | `bundle exec rspec spec/requests/cards_spec.rb` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 1 | CARD-06 | T-02-03 | POST /decks/:id/cards ignores front_image param | request | `bundle exec rspec spec/requests/cards_spec.rb` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 1 | CARD-03 | — | inline edit Turbo Frame row swap | system | `bundle exec rspec spec/system/deck_authoring_spec.rb` | ❌ W0 | ⬜ pending |
| 02-04-01 | 04 | 2 | CARD-05 | T-02-04 | POST /decks/:id/cards/imports preview returns table | request | `bundle exec rspec spec/requests/cards/imports_spec.rb` | ❌ W0 | ⬜ pending |
| 02-04-02 | 04 | 2 | CARD-05 | T-02-04 | paste import save blocked on duplicate front | request | `bundle exec rspec spec/requests/cards/imports_spec.rb` | ❌ W0 | ⬜ pending |
| 02-04-03 | 04 | 2 | CARD-05 | T-02-04 | PasteImportService 500 card limit enforced | unit | `bundle exec rspec spec/services/flashcards/paste_import_service_spec.rb` | ❌ W0 | ⬜ pending |
| 02-04-04 | 04 | 2 | CARD-05 | — | PasteImportService transaction rollback on error | unit | `bundle exec rspec spec/services/flashcards/paste_import_service_spec.rb` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `spec/system/` — 디렉토리 생성 (`mkdir -p spec/system`)
- [ ] `spec/system/deck_authoring_spec.rb` — Capybara 시스템 테스트 스텁 (CARD-03 인라인 편집)
- [ ] `spec/requests/decks_spec.rb` — 덱 CRUD + 3섹션 + 인증/인가 스텁
- [ ] `spec/requests/cards_spec.rb` — 카드 CRUD + image params 차단 스텁
- [ ] `spec/requests/cards/imports_spec.rb` — paste import preview/save 스텁
- [ ] `spec/services/flashcards/paste_import_service_spec.rb` — 서비스 단위 테스트 스텁
- [ ] `spec/support/system_test_helpers.rb` — Capybara 드라이버 설정 (spec/support/ 비어 있음 확인)
- [ ] `spec/support/request_helpers.rb` — sign_in 헬퍼 (spec/support/ 비어 있음 확인)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cmd+Enter 키보드 단축키 동작 | CARD-02 | JS 키보드 이벤트는 Capybara headless에서 메타키 시뮬레이션이 불안정 | 개발자 브라우저에서 덱 상세 → 카드 폼 → front 입력 후 Cmd+Enter → 저장 확인 |
| paste_import_controller.js 구분자 자동 감지 | CARD-05 | 클라이언트 JS 로직 — request spec으로 검증 불가 | 브라우저에서 paste import textarea에 Tab/Pipe/== 구분 텍스트 붙여넣기 → selectbox 자동 선택 확인 |
| 모바일 "저장하고 다음" 버튼 표시 | CARD-02 | 모바일 viewport 자동화 불안정 | Chrome DevTools 모바일 뷰에서 submit 버튼 노출 확인 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
