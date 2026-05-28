# Requirements: 낱말카드 (Flashcards) v1

**Defined:** 2026-05-29
**Core Value:** 학습 세션에서 카드를 평가하면 SM-2 알고리즘이 다음 복습 시각을 계산하고 Turbo Stream으로 즉시 다음 카드를 보여준다 — 이 사이클이 끊기면 모든 것이 무의미하다.

## v1 Requirements

### Data Models

- [ ] **MODEL-01**: `Deck` 모델은 `scope` enum(official/club/personal), `title`, `description`, `owner` polymorphic(nil for official), `forked_from_deck_id`, `featured_at` 컬럼을 가진다
- [ ] **MODEL-02**: `Card` 모델은 `deck_id`, `front`, `back`, `hint`(nullable), `tags`(string, 쉼표 구분), `card_type` enum(v1=basic), `position` 컬럼을 가진다
- [ ] **MODEL-03**: `CardReview` 모델은 `(user_id, card_id)` 유니크 제약을 가지며, `ease`, `interval_days`, `repetitions`, `next_review_at`, `last_reviewed_at`, `last_rating` 컬럼을 가진다
- [ ] **MODEL-04**: `CardReview` 테이블에 `(user_id, next_review_at)` 복합 인덱스가 존재한다
- [ ] **MODEL-05**: `TournamentEventDeck` 조인 테이블은 `tournament_event_id`, `deck_id`, `position` 컬럼을 가진다
- [ ] **MODEL-06**: `Card` 모델은 ActiveStorage `front_image`, `back_image` attachment를 선언한다 (UI는 숨김)
- [ ] **MODEL-07**: 모든 마이그레이션은 `up`/`down` 가역(reversible) 형태로 작성된다

### SM-2 Algorithm Service

- [ ] **SM2-01**: `Flashcards::Sm2Service` (또는 동등한 Ruby 서비스)는 외부 gem 없이 SM-2 알고리즘을 구현한다
- [ ] **SM2-02**: 서비스는 4단계 평가(1=다시, 2=어려움, 3=보통, 4=쉬움)를 입력으로 받아 `ease`, `interval_days`, `repetitions`, `next_review_at`을 반환한다
- [ ] **SM2-03**: 평가 1(다시)의 경우 interval_days가 1로 초기화되고 repetitions가 0으로 리셋된다
- [ ] **SM2-04**: 평가 4(쉬움)의 경우 ease factor가 증가하고 interval이 이전 대비 최소 2배 이상 늘어난다
- [ ] **SM2-05**: `next_review_at`은 KST 기준 `Time.current + interval_days.days`로 계산된다
- [ ] **SM2-06**: SM-2 서비스에 대한 단위 테스트(RSpec)가 존재하며, 4단계 평가 모두 커버한다

### Deck Management

- [ ] **DECK-01**: 인증된 사용자는 personal scope 덱을 생성할 수 있다
- [ ] **DECK-02**: site_admin(role_admin)은 official scope 덱을 생성할 수 있다
- [ ] **DECK-03**: approved 클럽 멤버는 소속 클럽의 club scope 덱을 생성할 수 있다
- [ ] **DECK-04**: official 덱은 모든 인증된 사용자가 읽기(목록, 상세)와 학습을 할 수 있다
- [ ] **DECK-05**: club 덱은 해당 클럽의 approved 멤버만 읽기와 학습을 할 수 있다
- [ ] **DECK-06**: personal 덱은 소유자 본인만 읽기, 학습, 수정, 삭제를 할 수 있다
- [ ] **DECK-07**: 덱 소유자(또는 club manager/site_admin)만 덱을 수정·삭제할 수 있다
- [ ] **DECK-08**: site_admin과 club manager(해당 클럽)는 club 덱의 `featured_at` 토글을 할 수 있다
- [ ] **DECK-09**: 덱을 삭제하면 소속 Card와 CardReview가 cascade 삭제된다

### Fork

- [ ] **FORK-01**: 인증된 사용자는 official 또는 club(접근 가능한) 덱을 자신의 personal 덱으로 fork할 수 있다
- [ ] **FORK-02**: fork 시 Card 레코드는 복사되지 않고, `forked_from_deck_id` 참조만 새 Deck에 저장된다 (ADR 0001)
- [ ] **FORK-03**: fork된 personal 덱의 CardReview는 원본 덱의 CardReview와 독립적이다

### Card Management

- [ ] **CARD-01**: 덱 소유자(또는 site_admin)는 카드를 생성할 수 있다 (single-card form)
- [ ] **CARD-02**: 단일 카드 폼은 "저장하고 다음" 버튼으로 연속 입력을 지원하며, 저장 후 동일 덱의 새 카드 폼으로 이동한다
- [ ] **CARD-03**: 덱 소유자(또는 site_admin)는 카드를 수정할 수 있다 (인라인 편집 — Turbo Frame)
- [ ] **CARD-04**: 덱 소유자(또는 site_admin)는 카드를 삭제할 수 있다 (cascade: CardReview도 삭제)
- [ ] **CARD-05**: Paste import — textarea에 붙여넣기 후 카드 간/면 간 구분자를 지정하면, 미리보기 후 일괄 저장된다
- [ ] **CARD-06**: `card_type` 컬럼은 존재하나, v1에서는 `basic` 타입만 지원한다

### SRS Study Session

- [ ] **STUDY-01**: 인증된 사용자는 `/decks/:id/study`에서 특정 덱의 due 카드 큐로 SRS 학습을 시작할 수 있다
- [ ] **STUDY-02**: 인증된 사용자는 `/study`에서 모든 접근 가능한 덱의 due 카드를 통합한 글로벌 큐로 학습할 수 있다
- [ ] **STUDY-03**: SRS 학습 중 카드 평가(`POST /card_reviews`)는 Turbo Stream으로 페이지 전환 없이 다음 카드를 화면에 표시한다
- [ ] **STUDY-04**: 4단계 평가 버튼(다시/어려움/보통/쉬움)이 카드 하단에 표시된다
- [ ] **STUDY-05**: 큐의 마지막 카드를 평가하면 "오늘 학습 완료" 상태 화면이 표시된다
- [ ] **STUDY-06**: due 카드는 `next_review_at <= Time.current`(KST) 조건으로 조회된다
- [ ] **STUDY-07**: CardReview가 없는 카드(신규 카드)도 due 카드로 포함된다

### Flip Browse Mode

- [ ] **BROWSE-01**: 인증된 사용자는 덱 상세 또는 학습 진입점에서 Flip browse 모드를 시작할 수 있다
- [ ] **BROWSE-02**: Flip browse는 카드를 클릭/탭하면 앞/뒤가 뒤집힌다 (CSS transform, Stimulus controller)
- [ ] **BROWSE-03**: Flip browse는 이전/다음 버튼으로 순서 탐색이 가능하다
- [ ] **BROWSE-04**: Flip browse는 CardReview를 생성·수정하지 않는다 (진도 미기록)
- [ ] **BROWSE-05**: Flip browse는 카드 셔플 옵션을 제공한다

### Authorization (Pundit)

- [ ] **AUTH-01**: `DeckPolicy`가 존재하며, scope별(official/club/personal) 읽기·수정·삭제 규칙을 구현한다
- [ ] **AUTH-02**: `CardPolicy`가 존재하며, `DeckPolicy`에 권한을 위임한다
- [ ] **AUTH-03**: `CardReviewPolicy`가 존재하며, `record.user == current_user` 조건을 강제한다
- [ ] **AUTH-04**: 모든 controller action에 `authorize` 호출이 존재한다 (Pundit default-deny)
- [ ] **AUTH-05**: 권한 없는 접근 시 Pundit::NotAuthorizedError가 처리되어 적절한 에러 응답이 반환된다
- [ ] **AUTH-06**: `TournamentEventDeck` 매핑 권한은 해당 토너먼트의 club_manager + site_admin으로 제한된다

### Navigation & Entry Points

- [ ] **NAV-01**: 유틸리티 dropdown에 "낱말카드" 링크가 추가된다 (포모도로 옆)
- [ ] **NAV-02**: 네비게이션 "낱말카드" 라벨 옆에 due 카운트 배지가 표시된다
- [ ] **NAV-03**: due 카운트 배지는 Solid Cache 1시간 TTL로 캐싱된다
- [ ] **NAV-04**: 학습 완료(CardReview 변경) 또는 카드 변경 시 해당 사용자의 due 카운트 캐시가 invalidate된다

### Decks Hub (`/decks`)

- [ ] **HUB-01**: `/decks`는 "오늘의 복습" hero 섹션(due 카운트 표시)을 포함한다
- [ ] **HUB-02**: `/decks`는 접근 가능한 덱을 official/club/personal 그룹으로 분류하여 표시한다
- [ ] **HUB-03**: 덱이 0개인 신규 사용자에게는 시드 덱 hero + "내 덱 만들기" + "붙여넣기 가져오기" CTA가 표시된다

### Statistics

- [ ] **STAT-01**: 사용자 프로필 또는 `/decks`에 Streak(연속 학습 일수, KST 자정 기준)이 표시된다
- [ ] **STAT-02**: "오늘의 현황"으로 오늘 학습 완료 수와 remaining due 카운트가 표시된다
- [ ] **STAT-03**: 덱 상세 페이지에 마스터리 % (`interval_days >= 21` 카드 비율)가 표시된다
- [ ] **STAT-04**: 7일 due 예상이 CSS 막대 차트로 시각화된다

### Tournament Integration

- [ ] **TOURN-01**: `TournamentEventDeck` 조인 테이블로 `tournament_event`에 N개의 덱을 매핑할 수 있다
- [ ] **TOURN-02**: 매핑 UI는 `tournament_events/:id/edit`에 존재하며, 후보 덱은 전체 official 덱 + 매핑자 소속 클럽의 club 덱이다
- [ ] **TOURN-03**: `tournament_events/:id` show 페이지 상단에 "이 종목 학습하기" 카드가 표시된다 (연결된 덱이 있을 때만)

### Seed Content

- [ ] **SEED-01**: `db/seeds/flashcards.yml`에 공식 덱 3종의 카드 데이터가 정의된다: "피클볼 기본 룰 30선"(30장), "영어 콜아웃 & 용어", "스코어링 시나리오 20"(20장)
- [ ] **SEED-02**: `db:seed` 실행 시 위 3종의 Deck과 Card가 생성된다 (멱등 — 중복 실행 시 중복 생성 없음)

### Error Handling & Security

- [ ] **SEC-01**: `bin/brakeman --no-pager` 실행 시 신규 경고가 0개다
- [ ] **SEC-02**: 모든 사용자 입력은 controller 또는 model layer에서 strong parameters / validation으로 검증된다
- [ ] **SEC-03**: 인증되지 않은 사용자는 학습, 카드 생성, CardReview 생성 API에 접근할 수 없다 (401/redirect)
- [ ] **SEC-04**: 권한 없는 리소스 접근 시 403 또는 적절한 redirect가 반환된다

### Testing

- [ ] **TEST-01**: SM-2 서비스에 대한 RSpec 단위 테스트가 존재한다 (4단계 평가 시나리오 모두 포함)
- [ ] **TEST-02**: `DeckPolicy`, `CardPolicy`, `CardReviewPolicy`에 대한 RSpec policy 테스트가 존재한다
- [ ] **TEST-03**: SRS 학습 플로우(카드 평가 → Turbo Stream next-card)에 대한 request spec이 존재한다
- [ ] **TEST-04**: Deck, Card, CardReview 모델에 대한 RSpec model spec이 존재한다 (validations, associations, scopes)
- [ ] **TEST-05**: FactoryBot factory가 Deck, Card, CardReview에 대해 정의된다

---

## v2 Requirements

### Notifications

- **NOTF-01**: 사용자는 due 카드가 있을 때 이메일 알림을 받는다
- **NOTF-02**: 사용자는 Web push 알림으로 복습 리마인더를 받는다
- **NOTF-03**: 사용자는 알림 수신 여부를 설정할 수 있다

### Advanced Card Types

- **CTYPE-01**: Cloze(빈칸 채우기) 카드 타입이 지원된다
- **CTYPE-02**: 객관식 카드 타입이 지원된다
- **CTYPE-03**: 오디오 첨부 카드 타입이 지원된다

### Gamification

- **GAME-01**: 클럽 내 학습 리더보드가 제공된다
- **GAME-02**: 학습 달성 배지 시스템이 제공된다

### Public UGC

- **UGC-01**: 사용자는 personal 덱을 전체 공개로 전환할 수 있다 (모더레이션 체계 전제)

### Advanced Statistics

- **ADVSTAT-01**: 히트맵 형태의 학습 기록 캘린더가 제공된다
- **ADVSTAT-02**: 카드별 정확도 추이 그래프가 제공된다

### Onboarding

- **ONBOARD-01**: 클럽 manage 페이지에서 클럽 덱 생성 유도 배너가 1회 표시된다 (dismiss 가능)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| 공개 UGC (개인 덱 전체 공개) | 모더레이션 비용 과다. 스팸·오류 룰 카드가 플랫폼 신뢰도 훼손. v2 검토 |
| 카드 타입 변종 (Cloze, 객관식, 오디오) | v1 SM-2 검증 전 UI 복잡도 폭발. `card_type` enum 컬럼만 확보 |
| 이메일/Web push/Telegram 알림 | 인앱 배지로 충분히 검증 먼저. v2 검토 |
| 클럽 리더보드 / 뱃지 / 게임화 | 룰 습득이 목표 — 경쟁 구조는 "빨리 넘기기" 부정행위 유도. v2 검토 |
| 카드 텍스트 버전 관리 | ADR 0001 위반. Card 공유 모델에서 버전 이력은 CardReview와 충돌 |
| 사용자별 타임존 설정 | KST 하드코딩 기존 패턴 유지 (국내 동호회 서비스) |
| CSV 업로드 | Paste import로 대체. 서버 파싱·인코딩 에러 처리 복잡도 제거 |
| Soft delete | 기존 패턴 불일치. cascade hard delete 유지 |
| Test/Match/Spell 게임 모드 | 기본 SRS 우선 검증 후 |
| Game session 연결 | 토너먼트 이벤트 연결까지만 v1 범위 |
| 오디오 첨부, 코트 다이어그램 에디터 | 피클볼 특화 미디어, 요구사항 미검증 |
| ActiveStorage S3 연동 (UI 노출) | 이미지 attachment 컬럼은 구현, S3 미설정 — UI는 숨김 처리 |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MODEL-01 | Phase 1 | Pending |
| MODEL-02 | Phase 1 | Pending |
| MODEL-03 | Phase 1 | Pending |
| MODEL-04 | Phase 1 | Pending |
| MODEL-05 | Phase 1 | Pending |
| MODEL-06 | Phase 1 | Pending |
| MODEL-07 | Phase 1 | Pending |
| SM2-01 | Phase 1 | Pending |
| SM2-02 | Phase 1 | Pending |
| SM2-03 | Phase 1 | Pending |
| SM2-04 | Phase 1 | Pending |
| SM2-05 | Phase 1 | Pending |
| SM2-06 | Phase 1 | Pending |
| AUTH-01 | Phase 1 | Pending |
| AUTH-02 | Phase 1 | Pending |
| AUTH-03 | Phase 1 | Pending |
| AUTH-04 | Phase 1 | Pending |
| AUTH-05 | Phase 1 | Pending |
| AUTH-06 | Phase 1 | Pending |
| TEST-04 | Phase 1 | Pending |
| TEST-05 | Phase 1 | Pending |
| DECK-01 | Phase 2 | Pending |
| DECK-02 | Phase 2 | Pending |
| DECK-03 | Phase 2 | Pending |
| DECK-04 | Phase 2 | Pending |
| DECK-05 | Phase 2 | Pending |
| DECK-06 | Phase 2 | Pending |
| DECK-07 | Phase 2 | Pending |
| DECK-08 | Phase 2 | Pending |
| DECK-09 | Phase 2 | Pending |
| CARD-01 | Phase 2 | Pending |
| CARD-02 | Phase 2 | Pending |
| CARD-03 | Phase 2 | Pending |
| CARD-04 | Phase 2 | Pending |
| CARD-06 | Phase 2 | Pending |
| HUB-01 | Phase 2 | Pending |
| HUB-02 | Phase 2 | Pending |
| HUB-03 | Phase 2 | Pending |
| NAV-01 | Phase 2 | Pending |
| NAV-02 | Phase 2 | Pending |
| NAV-03 | Phase 2 | Pending |
| NAV-04 | Phase 2 | Pending |
| SEED-01 | Phase 2 | Pending |
| SEED-02 | Phase 2 | Pending |
| TEST-02 | Phase 2 | Pending |
| STUDY-01 | Phase 3 | Pending |
| STUDY-02 | Phase 3 | Pending |
| STUDY-03 | Phase 3 | Pending |
| STUDY-04 | Phase 3 | Pending |
| STUDY-05 | Phase 3 | Pending |
| STUDY-06 | Phase 3 | Pending |
| STUDY-07 | Phase 3 | Pending |
| BROWSE-01 | Phase 3 | Pending |
| BROWSE-02 | Phase 3 | Pending |
| BROWSE-03 | Phase 3 | Pending |
| BROWSE-04 | Phase 3 | Pending |
| BROWSE-05 | Phase 3 | Pending |
| TEST-01 | Phase 3 | Pending |
| TEST-03 | Phase 3 | Pending |
| CARD-05 | Phase 4 | Pending |
| FORK-01 | Phase 4 | Pending |
| FORK-02 | Phase 4 | Pending |
| FORK-03 | Phase 4 | Pending |
| STAT-01 | Phase 4 | Pending |
| STAT-02 | Phase 4 | Pending |
| STAT-03 | Phase 4 | Pending |
| STAT-04 | Phase 4 | Pending |
| TOURN-01 | Phase 5 | Pending |
| TOURN-02 | Phase 5 | Pending |
| TOURN-03 | Phase 5 | Pending |
| SEC-01 | Phase 1 | Pending |
| SEC-02 | Phase 1 | Pending |
| SEC-03 | Phase 1 | Pending |
| SEC-04 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 64 total
- Mapped to phases: 64
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-29*
*Last updated: 2026-05-29 — initial definition from PROJECT.md + FEATURES.md research*
