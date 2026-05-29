---
phase: 01-foundations
verified: 2026-05-30T00:00:00Z
status: passed
score: 8/8
overrides_applied: 0
---

# Phase 01: Foundations — Verification Report

**Phase Goal:** 데이터 계층(모델·마이그레이션·시드·SM-2 서비스)이 콘솔에서 완전히 동작하고, 모든 후속 phase가 의존하는 정책 base와 팩토리가 자리잡는다.
**Verified:** 2026-05-30
**Status:** passed
**Re-verification:** No — initial verification

---

## Commit History Verification

SUMMARY.md에 기록된 22개 커밋이 실제 `git log`에 존재함을 확인.

- 가장 오래된: `8542fef` chore(01-01): install ActiveStorage tables
- 가장 최신: `f6536b9` docs(01-01): SUMMARY.md + PITFALLS SM-2 mapping update
- 22개 전체 커밋 순서 일치 확인 완료.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | bin/rails db:migrate 후 5개 테이블 + ActiveStorage 3개 + 인덱스/FK 모두 존재 | VERIFIED | db/schema.rb 확인: decks, cards, card_reviews, tournament_event_decks + 3 ActiveStorage 테이블; FK cascade 7개 (cards→decks, card_reviews→users, card_reviews→cards, tournament_event_decks→decks, tournament_event_decks→tournament_events, decks self-FK nullify) |
| 2 | db:rollback STEP=5 — 5개 Phase 1 마이그레이션 모두 가역 | VERIFIED | 실행 결과: `bin/rails db:rollback STEP=5` → 5개 migration 모두 clean revert (exit 0); `bin/rails db:migrate` 재적용도 clean |
| 3 | Deck.new / Card.new / CardReview.new / TournamentEventDeck.new 가 enum/association/validation 메서드에 정상 응답 | VERIFIED | 코드 검증: deck.rb(39줄), card.rb(41줄), card_review.rb(10줄), tournament_event_deck.rb(7줄) 확인; spec/models 4개 파일 모두 green (265 examples, 0 failures 중 포함) |
| 4 | Flashcards::Sm2Service.call — 모든 rating [1,2,3,4] 에 대해 ease >= 1.3, interval_days >= 1, QUALITY_MAP {1=>1,2=>3,3=>4,4=>5} | VERIFIED | spec/services/flashcards/sm2_service_spec.rb 실행: **35 examples, 0 failures**; QUALITY_MAP = {1=>1, 2=>3, 3=>4, 4=>5}.freeze, EASE_FLOOR = 1.3, ArgumentError for [0,5,-1,"1",nil] 모두 포함 |
| 5 | Flashcards::ForkDeckService.call — 새 personal deck의 position이 1..n contiguous, forked_from_deck_id 설정, CardReview 0건 | VERIFIED | spec/services/flashcards/fork_deck_service_spec.rb 실행: **35 examples (SM2+ForkDeck total)**, position renormalization [1,3,5,10] → [1,2,3,4] 검증; CardReview 미복사; 트랜잭션 롤백 케이스 포함 |
| 6 | bin/rails db:seed 후 Deck.official.count == 3, 덱별 카드 수 30/25/20; 2회 실행 시 신규 row 0 | VERIFIED | 실행 결과: `official count: 3` / 피클볼 기본 룰 30선: 30 / 영어 콜아웃 & 용어: 25 / 스코어링 시나리오 20: 20; 2회 실행 동일 결과 (idempotent) |
| 7 | DeckPolicy: personal_owner? 동작, Scope#resolve = scope.none, site_admin? bypass, CardReviewPolicy: DeckPolicy#show? 미포함 (TODO(phase-4) 마커) | VERIFIED | deck_policy.rb(26줄): show?/update?/destroy? = personal_owner?, Scope→scope.none, site_admin? bypass 확인; card_review_policy.rb(24줄): create? = user.present? && record.user == user (DeckPolicy#show? 불호출 확인); TODO(phase-4) 마커 4개, TODO(phase-5) 마커 1개 확인 |
| 8 | FactoryBot.lint 통과 — :deck의 :official/:club/:personal 포함 모든 팩토리/트레잇 clean build | VERIFIED | spec/factories_spec.rb → 419 examples 전체 포함 0 failures; spec/factories/decks.rb: official/club/personal/featured/forked 트레잇 구현 확인 |

**Score:** 8/8 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/20260528214858_create_active_storage_tables.active_storage.rb` | ActiveStorage 3 테이블 | VERIFIED | 존재, schema.rb에 3테이블 반영 |
| `db/migrate/20260528215029_create_decks.rb` | decks 테이블 + 4 인덱스 + self-FK nullify | VERIFIED | schema.rb: index_decks_on_owner_type_and_owner_id, index_decks_on_scope, index_decks_on_forked_from_deck_id, index_decks_on_scope_and_featured_at; FK on_delete: nullify |
| `db/migrate/20260528215110_create_cards.rb` | cards 테이블 + deck_id FK cascade + (deck_id, position) 인덱스 | VERIFIED | schema.rb: index_cards_on_deck_id_and_position, add_foreign_key "cards", "decks", on_delete: :cascade |
| `db/migrate/20260528215136_create_card_reviews.rb` | card_reviews + (user_id,card_id) unique + (user_id,next_review_at) 인덱스 | VERIFIED | schema.rb: index_card_reviews_on_user_id_and_card_id unique:true, index_card_reviews_on_user_id_and_next_review_at; 두 FK cascade |
| `db/migrate/20260528215206_create_tournament_event_decks.rb` | TED 조인 테이블 + 2 named 인덱스 | VERIFIED | schema.rb: index_ted_on_event_and_deck unique:true, index_ted_on_event_and_position |
| `app/models/deck.rb` | enum :scope, polymorphic owner, forked_from, has_many :cards dependent:destroy, owner_matches_scope | VERIFIED | 39줄; enum :scope {official:0,club:1,personal:2}; belongs_to :owner, polymorphic:true, optional:true; owner_matches_scope validation (3 분기 모두 구현) |
| `app/models/card.rb` | has_one_attached, 이미지 validation, has_many :card_reviews dependent:destroy, .ordered | VERIFIED | 41줄; front_image/back_image attached; ALLOWED_IMAGE_TYPES, MAX_IMAGE_BYTES; Korean error messages; NOTE(phase-2) comment 포함 |
| `app/models/card_review.rb` | uniqueness(user_id,card_id), ease >= 1.3, last_rating 1..4 or nil | VERIFIED | 10줄; 모든 validation 구현 |
| `app/models/tournament_event_deck.rb` | belongs_to, uniqueness(tournament_event_id, deck_id) | VERIFIED | 7줄; belongs_to :tournament_event, :deck; uniqueness :deck_id scoped_to :tournament_event_id |
| `app/services/flashcards/sm2_service.rb` | EASE_FLOOR=1.3, QUALITY_MAP frozen, Result struct, ArgumentError on invalid rating, no AR | VERIFIED | 56줄; QUALITY_MAP = {1=>1,2=>3,3=>4,4=>5}.freeze; Result = Struct.new(..., keyword_init: true); rating.is_a?(Integer) 체크; AR 의존성 없음 |
| `app/services/flashcards/fork_deck_service.rb` | each_with_index position 1..n, transaction, CardReview 미생성 | VERIFIED | 51줄; ActiveRecord::Base.transaction; each_with_index { |c,idx| position: idx+1 }; CardReview 생성 코드 없음 |
| `app/policies/deck_policy.rb` | show?/update?/destroy?=personal_owner?, Scope→scope.none, site_admin? bypass | VERIFIED | 26줄; 명세 정확히 구현 |
| `app/policies/card_policy.rb` | DeckPolicy 위임, Scope→scope.none | VERIFIED | 17줄; delegate to :deck_policy |
| `app/policies/card_review_policy.rb` | create?=user&&record.user==user, DeckPolicy#show? 미포함, Scope→user's reviews | VERIFIED | 24줄; TODO(phase-4) 2개; DeckPolicy 미호출 확인 |
| `app/policies/tournament_event_deck_policy.rb` | default-deny, Scope→scope.none, TODO(phase-5) | VERIFIED | 11줄; ApplicationPolicy 상속 (default deny); TODO(phase-5) 마커 |
| `db/seeds/flashcards.yml` | 3 official decks, expected_card_count 선언 | VERIFIED | 존재 (75 draft 카드 포함) |
| `db/seeds/flashcards.rb` | idempotent, find_or_initialize_by, expected_count gate | VERIFIED | 55줄; YAML.safe_load_file; find_or_create_by! for decks; find_or_initialize_by(front:) for cards; draft 경고 발행 |
| `spec/factories/decks.rb` | :official/:club/:personal/:featured/:forked 트레잇 | VERIFIED | 36줄; 5 트레잇 모두 구현; :official에서 owner:nil 명시 |
| `spec/factories/card_reviews.rb` | :due/:mature 트레잇 | VERIFIED | 29줄; :due (next_review_at: 1.hour.ago), :mature (interval_days: 21, repetitions: 5) |
| `spec/factories/cards.rb` | sequence front/back/position | VERIFIED | 존재 |
| `spec/factories/tournament_event_decks.rb` | tournament_event + :official deck 연결 | VERIFIED | 존재 |
| `spec/factories_spec.rb` | FactoryBot.lint | VERIFIED | 419 examples, 0 failures 포함 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `app/models/deck.rb` | owner (polymorphic) → User, Club, nil | `belongs_to :owner, polymorphic: true, optional: true` + `owner_matches_scope` | VERIFIED | deck.rb:2 |
| `app/models/card.rb` | card_reviews (cascade delete) | `has_many :card_reviews, dependent: :destroy` | VERIFIED | card.rb:11 |
| `db/migrate/*_create_card_reviews.rb` | (user_id, next_review_at) composite index | `add_index :card_reviews, [:user_id, :next_review_at]` | VERIFIED | schema.rb:55: `index_card_reviews_on_user_id_and_next_review_at` |
| `app/services/flashcards/sm2_service.rb` | QUALITY_MAP {1=>1,2=>3,3=>4,4=>5} | frozen constant | VERIFIED | sm2_service.rb:14 |
| `app/services/flashcards/fork_deck_service.rb` | 새 Deck.cards position 1..n contiguous | `each_with_index { |c,idx| position: idx+1 }` | VERIFIED | fork_deck_service.rb:34-42 |
| `db/seeds/flashcards.rb` | `db/seeds.rb` | `load Rails.root.join("db/seeds/flashcards.rb")` | VERIFIED | seeds.rb:223 |

---

## Data-Flow Trace (Level 4)

Phase 1은 HTTP surface가 없으며 데이터 렌더링 컴포넌트가 없음 (모델, 서비스, 정책 스텁, 팩토리, 시드 로더만 포함). Level 4 적용 불필요.

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| SM-2 boundary table (8 cases + extras) | `bundle exec rspec spec/services/flashcards/sm2_service_spec.rb` | 35 examples, 0 failures | PASS |
| ForkDeckService — position renorm + CardReview isolation | `bundle exec rspec spec/services/flashcards/fork_deck_service_spec.rb` | 35 examples combined, 0 failures | PASS |
| Seed idempotency — 2회 실행 동일 카운트 | `bin/rails db:seed` 2회 | 3 official decks, 75 official cards (양쪽 동일) | PASS |
| Migration rollback round-trip | `bin/rails db:rollback STEP=5 && bin/rails db:migrate` | exit 0, 5 migrations clean revert/re-apply | PASS |
| Full RSpec suite | `bundle exec rspec` | 419 examples, 0 failures | PASS |
| Brakeman security scan | `bin/brakeman --no-pager` | 3 warnings (전부 Phase 1 이전 pre-existing) — 신규 0 | PASS |

---

## Probe Execution

Phase 1 PLAN.md에 별도 probe 스크립트 없음. 위 Behavioral Spot-Checks가 동등한 검증 역할.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| F1-DECK | 01-01-PLAN.md | Deck 모델 (3-tier scope enum, polymorphic owner, forked_from, featured_at) | SATISFIED | app/models/deck.rb + schema.rb 확인 |
| F1-CARD | 01-01-PLAN.md | Card 모델 (front/back/hint/tags/card_type/position, ActiveStorage) | SATISFIED | app/models/card.rb + schema.rb 확인 |
| F1-CR | 01-01-PLAN.md | CardReview 모델 ((user_id,card_id) unique, ease, interval, repetitions, next_review_at) | SATISFIED | app/models/card_review.rb + schema.rb 확인 |
| F1-TED | 01-01-PLAN.md | TournamentEventDeck join (schema only) | SATISFIED | app/models/tournament_event_deck.rb + schema.rb 확인 |
| F1-IDX | 01-01-PLAN.md | (user_id, next_review_at) 필수 인덱스 | SATISFIED | schema.rb:55 `index_card_reviews_on_user_id_and_next_review_at` |
| F1-SM2 | 01-01-PLAN.md | SM-2 알고리즘 Ruby 서비스, gem 없음, QUALITY_MAP locked | SATISFIED | sm2_service_spec.rb 35/0; QUALITY_MAP 상수 동일 |
| F1-FORK | 01-01-PLAN.md | ForkDeckService — position 1..n, CardReview 미복사 | SATISFIED | fork_deck_service_spec.rb 통과; each_with_index 구현 |
| F1-FAC | 01-01-PLAN.md | FactoryBot 팩토리 4종 (deck 3 scopes, card, card_review, tournament_event_deck) | SATISFIED | FactoryBot.lint 419/0 |
| F1-SEED | 01-01-PLAN.md | 시드 구조 (flashcards.yml + 3 공식 덱) | SATISFIED | Deck.official.count==3; 30/25/20 카드 |
| F1-POL | 01-01-PLAN.md | DeckPolicy/CardPolicy/CardReviewPolicy stub + default deny | SATISFIED | 4 policy 파일 확인; Scope#resolve=scope.none |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `db/seeds/flashcards.yml` | all cards | `draft: true` (75/75 cards) | INFO | AI 초안 카드 — 운영 단계에서 검토 예정; 시드 로더가 경고 발행 (블로킹 아님); SUMMARY.md §3에 명시적으로 기록됨 |

TBD/FIXME/XXX 마커: **0건** (rg 스캔 결과)

TODO(phase-4) 마커: **4건** (deck_policy.rb:14, card_policy.rb:9, card_review_policy.rb:6, card_review_policy.rb:19) — 모두 Phase 4 참조 포함, 허용됨

TODO(phase-5) 마커: **1건** (tournament_event_deck_policy.rb:7) — Phase 5 참조 포함, 허용됨

---

## ROADMAP Success Criteria — Final Check

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC-1 | `bin/rails db:migrate` green; `bin/rails db:rollback STEP=4` (실제 STEP=5) 모두 가역 | VERIFIED | `db:rollback STEP=5` clean; `db:migrate` re-apply clean. ROADMAP 문서의 STEP=4는 ActiveStorage 포함 시 STEP=5가 정확 — PLAN.md §objective에 이미 문서화됨 |
| SC-2 | db:seed 후 `Deck.official.count == 3`, 각 덱 카드 수 YAML 기대치(30/25/20) 일치 | VERIFIED | 실행 결과: 피클볼 기본 룰 30선: 30, 영어 콜아웃 & 용어: 25, 스코어링 시나리오 20: 20 |
| SC-3 | `bundle exec rspec spec/services/flashcards/sm2_service_spec.rb` green — boundary cases | VERIFIED | 35 examples, 0 failures |
| SC-4 | ForkDeckService.call 후 position 1..n contiguous, CardReview 0건 | VERIFIED | spec/services/flashcards/fork_deck_service_spec.rb green; position renorm [1,3,5,10]→[1,2,3,4] 검증 |
| SC-5 | `bin/brakeman --no-pager` 신규 경고 0 | VERIFIED | 경고 3→3, 신규 0 (3개 모두 Phase 1 이전 pre-existing: admin/database_backups, admin/users, admin/data_management) |
| SC-6 | `bundle exec rspec` 전체 green | VERIFIED | 419 examples, 0 failures |

---

## Human Verification Required

없음. Phase 1은 HTTP surface가 없고 UI가 없으므로 자동화 검증이 완전히 가능합니다.

---

## Gaps Summary

갭 없음. 6개 ROADMAP Success Criteria 및 8개 PLAN must-have truths 모두 검증되었습니다.

**Note — ROADMAP 문서 minor 불일치 (블로커 아님):**
ROADMAP.md SC-1에 `db:rollback STEP=4`라고 기재되어 있으나, ActiveStorage 설치가 Phase 1 deliverable에 포함됨에 따라 실제 필요 STEP=5입니다. 이는 01-01-PLAN.md §objective에 이미 교정 문서화되어 있으며 실제 동작은 정확합니다. ROADMAP.md의 STEP=4 → STEP=5 수정을 권장하나 Phase 목표 달성을 막는 블로커가 아닙니다.

---

_Verified: 2026-05-30_
_Verifier: Claude (gsd-verifier)_
