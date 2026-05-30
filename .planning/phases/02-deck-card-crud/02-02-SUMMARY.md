---
phase: 02-deck-card-crud
plan: "02"
subsystem: deck-crud-ui
tags:
  - decks
  - controller
  - views
  - pundit
  - nav
  - wave-1
dependency_graph:
  requires:
    - "02-01 — routes (decks/cards/imports) + spec stubs (decks_spec.rb)"
    - "Phase 1 — Deck model + DeckPolicy stub + Card model"
  provides:
    - "app/controllers/decks_controller.rb → full CRUD with Pundit + explicit 3-scope queries"
    - "app/views/decks/ → 6 view files (index/show/new/edit/_form/_deck)"
    - "app/views/layouts/application.html.erb → 낱말카드 nav entry point"
  affects:
    - "Wave 2 (02-03) — depends on @deck, @cards, id=deck-cards-{id}, id=deck-add-form-{id} containers"
tech_stack:
  added: []
  patterns:
    - "allow_unauthenticated_access only: [:index, :show] — public read for official decks"
    - "Deck.where(scope:) explicit 3-query pattern (no policy_scope — DeckPolicy::Scope = scope.none)"
    - "Deck.new(deck_params.merge(scope: :personal, owner: Current.user)) — owner fixed server-side"
    - "authorize @deck conditional on deck.personal? in show action"
    - "cl-page > cl-hero / cl-content structure matching flash_meetups pattern"
    - "TDD RED->GREEN with test(02-02)/feat(02-02) commit gate"
key_files:
  created:
    - app/controllers/decks_controller.rb
    - app/views/decks/index.html.erb
    - app/views/decks/show.html.erb
    - app/views/decks/new.html.erb
    - app/views/decks/edit.html.erb
    - app/views/decks/_form.html.erb
    - app/views/decks/_deck.html.erb
  modified:
    - app/views/layouts/application.html.erb (line 179 — nav dropdown 낱말카드 추가)
    - spec/requests/decks_spec.rb (pending stubs -> 12 real examples, all GREEN)
decisions:
  - "l(deck.updated_at, format: :short) -> deck.updated_at.strftime('%Y.%m.%d') — ko.yml에 time.formats.short 미정의 (KISS: inline format)"
  - "비인증 GET /decks는 redirect 아닌 200 (allow_unauthenticated_access) — plan must_haves가 /decks/new만 redirect 명시"
  - "Pundit NotAuthorizedError -> redirect_to(root_path) (ApplicationController#user_not_authorized) — 403 아닌 302"
  - "plan critical_constraint 준수: policy_scope(Deck) 호출 0건"
metrics:
  duration: "~18 minutes"
  completed: "2026-05-30T01:20:38Z"
  tasks_completed: 3
  files_modified: 9
---

# Phase 02 Plan 02: Deck CRUD + Views + Nav Entry Summary

Wave 1 목표: Wave 0이 생성한 `spec/requests/decks_spec.rb` pending 10개를 실제 12개 example로 교체하고 모두 GREEN으로 전환. DecksController CRUD + 6개 뷰 + nav 진입점을 구현했다.

## What Was Built

### DecksController 액션별 책임 매트릭스

| 액션 | Auth | authorize | 쿼리 방식 | Redirect |
|------|------|-----------|----------|---------|
| index | 비인증 허용 | 없음 | Deck.where(scope:) 3종 명시 | — |
| show | 비인증 허용 | @deck.personal?일 때만 | Deck.find | — |
| new | 필수 | authorize @deck | — | — |
| create | 필수 | authorize @deck | — | deck_path(@deck) |
| edit | 필수 | authorize_deck! | — | — |
| update | 필수 | authorize_deck! | — | deck_path(@deck) |
| destroy | 필수 | authorize_deck! | — | decks_path |

### 뷰 파일 역할

| 파일 | 역할 |
|------|------|
| `app/views/decks/index.html.erb` | 3-state 분기: 비인증(공식만) / 0개 덱(hero) / 1+개(3섹션) |
| `app/views/decks/show.html.erb` | 덱 상세 + Wave 2 placeholder containers |
| `app/views/decks/new.html.erb` | cl-page > cl-content--form > cl-form-card 구조 |
| `app/views/decks/edit.html.erb` | new.html.erb 동일 구조, eyebrow만 다름 |
| `app/views/decks/_form.html.erb` | form_with model: deck + title/description 필드 |
| `app/views/decks/_deck.html.erb` | scope 배지 + 제목 + 카드수/날짜 |

### Nav 수정 위치

파일: `app/views/layouts/application.html.erb`
Line 179 — 퍼즐조각맞추기(line 176) 바로 다음, 유틸리티 dropdown 그룹 내:

```erb
<%= link_to decks_path, class: "nav__dropdown-item" do %>
  <iconify-icon icon="lucide:layers"></iconify-icon><span>낱말카드</span>
<% end %>
```

신규 CSS 없음 — `nav__dropdown-item` 재사용. Due 카운트 배지(NAV-02)는 Phase 5 예약.

### spec/requests/decks_spec.rb GREEN 전환

| 테스트 그룹 | 이전 (pending) | 이후 |
|------------|--------------|------|
| GET /decks (비인증) | 1 pending | 1 PASS |
| GET /decks (0 덱 사용자) | 1 pending | 1 PASS |
| GET /decks (덱 보유) | 1 pending | 1 PASS |
| GET /decks (클럽 섹션 숨김) | 1 pending | 1 PASS |
| GET /decks nav 낱말카드 | 1 pending | 1 PASS |
| GET /decks/new (비인증 redirect) | — | 1 PASS (신규) |
| GET /decks/new (인증) | — | 1 PASS (신규) |
| POST /decks (생성) | 1 pending | 1 PASS |
| POST /decks (비인증) | 1 pending | 1 PASS |
| PATCH /decks/:id (본인) | 1 pending | 1 PASS |
| PATCH /decks/:id (타인) | 1 pending | 1 PASS |
| DELETE /decks/:id (cascade) | 1 pending | 1 PASS |
| **합계** | **10 pending** | **12 GREEN** |

### T-02-01 ~ T-02-04 Mitigation 검증

| Threat ID | Mitigation | 검증 |
|-----------|-----------|------|
| T-02-01 | `deck_params` — `permit(:title, :description)` only | `grep permit` → owner/scope/owner_id/owner_type 없음 확인 |
| T-02-02 | `authorize @deck` → `personal_owner?` — IDOR 차단 | "타인 덱 PATCH" spec → redirect_to(root_path) 확인 |
| T-02-03 | `Deck.new(scope: :personal, owner: Current.user)` 강제 | POST 후 `deck.scope == "personal"` 검증 확인 |
| T-02-04 | `authenticated?` 가드, show에서 `personal?`일 때 `authorize` | 비인증 GET /decks → 200 (공식만) 확인 |

### Wave 2 의존 인터페이스

Wave 2(02-03, CardsController)가 의존할 인터페이스:

| 인터페이스 | 위치 | 설명 |
|-----------|------|------|
| `@deck` | DecksController#show | 덱 레코드 |
| `@cards` | DecksController#show | `@deck.cards.order(:position, :id)` |
| `id="deck-cards-#{@deck.id}"` | show.html.erb line 32 | 카드 목록 컨테이너 (Turbo Stream 타겟) |
| `id="deck-add-form-#{@deck.id}"` | show.html.erb line 33 | 카드 추가 폼 컨테이너 (Turbo Stream 타겟) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] l(deck.updated_at, format: :short) Translation missing**
- **Found during:** Task 2 GREEN 실행
- **Issue:** `config/locales/ko.yml`에 `time.formats.short` 미정의 → TranslationMissing 오류
- **Fix:** `l(deck.updated_at, format: :short)` → `deck.updated_at.strftime('%Y.%m.%d')` (ko.yml 수정 없이 inline format)
- **Files modified:** `app/views/decks/_deck.html.erb`
- **Commit:** a8bf30a

**2. [Rule 2 - Missing] 비인증 사용자 테스트에 공식 덱 생성 필요**
- **Found during:** Task 1 GREEN 실행
- **Issue:** "비인증 사용자 공식 섹션 렌더" 테스트에서 공식 덱이 없으면 섹션 헤딩도 미노출 (덱이 있을 때만 섹션 렌더)
- **Fix:** 비인증 context에 `before { create(:deck, :official) }` 추가
- **Files modified:** `spec/requests/decks_spec.rb`
- **Commit:** a8bf30a

### CLAUDE.md Constraint Honored

`.claude/rules/controllers.md`는 `policy_scope(Model)` 사용을 권장하지만, 본 plan의 `<critical_constraints>`와 CONTEXT.md가 `DeckPolicy::Scope = scope.none` stub으로 인해 절대 금지. **Plan 우선** — 명시적 3종 쿼리 패턴 사용.

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED | 78fa1ff `test(02-02): add failing request specs for Deck CRUD (RED)` | PASS |
| GREEN | a8bf30a `feat(02-02): implement DecksController CRUD + 6 views + nav entry (GREEN)` | PASS |
| REFACTOR | 없음 (코드 품질 충분) | N/A |

## Commits

| Task | Commit | Message |
|------|--------|---------|
| RED (Task 1+2) | 78fa1ff | test(02-02): add failing request specs for Deck CRUD (RED) |
| GREEN (Task 1+2+3) | a8bf30a | feat(02-02): implement DecksController CRUD + 6 views + nav entry (GREEN) |

## Self-Check: PASSED

- app/controllers/decks_controller.rb: FOUND
- app/views/decks/index.html.erb: FOUND
- app/views/decks/show.html.erb: FOUND
- app/views/decks/new.html.erb: FOUND
- app/views/decks/edit.html.erb: FOUND
- app/views/decks/_form.html.erb: FOUND
- app/views/decks/_deck.html.erb: FOUND
- app/views/layouts/application.html.erb: modified (decks_path line 179)
- spec/requests/decks_spec.rb: 12 examples, 0 failures
- policy_scope(Deck): 0건
- authorize count: 6
- brakeman: 신규 경고 0건
