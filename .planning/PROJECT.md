# 낱말카드 (Flashcards) v1

## What This Is

PBPlayground의 피클볼 룰·용어 학습용 SRS(간격 반복) 카드 시스템. 동호인들이 룰 분쟁 없이 경기할 수 있도록 Quizlet 형태의 학습 카드를 제공하되, 클럽 단위 학습·토너먼트 종목 연결이라는 플랫폼 고유 차별점을 더한다. 유틸리티 드롭다운 메뉴(포모도로 옆)에 신설된다.

## Core Value

학습 세션에서 카드를 평가하면 SM-2 알고리즘이 다음 복습 시각을 계산하고 Turbo Stream으로 즉시 다음 카드를 보여준다 — 이 사이클이 끊기면 모든 것이 무의미하다.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Deck 모델 (3-tier)**
- [ ] `Deck` — `scope` enum (official/club/personal), `owner` polymorphic (nil for official), `forked_from_deck_id`, `featured_at`
- [ ] Official 덱: site_admin 작성, 전체 읽기/학습/fork 가능
- [ ] Club 덱: approved 멤버 작성, manager+owner+site_admin 모더레이션·featured 토글
- [ ] Personal 덱: 본인 전용, 비공개
- [ ] Fork: 공식/클럽 덱 → 개인 덱 복제 (CardReview 상태는 복사하지 않음)

**Card 모델**
- [ ] `Card` — `front`, `back`, `hint` (optional), `tags` (string, 쉼표 구분), `card_type` enum (v1=basic), `position`
- [ ] ActiveStorage `front_image`, `back_image` — 모델/마이그레이션은 구현, UI는 기본 숨김 (S3 미설정)

**CardReview (SRS 상태)**
- [ ] `CardReview` — `(user_id, card_id)` 유니크, `ease`, `interval_days`, `repetitions`, `next_review_at`, `last_reviewed_at`, `last_rating`
- [ ] SM-2 알고리즘 Ruby 서비스 자작 (gem 없음)
- [ ] 4단계 평가: 다시(1) / 어려움(2) / 보통(3) / 쉬움(4)
- [ ] 인덱스: `(user_id, next_review_at)` 필수

**학습 모드 2종**
- [ ] SRS 학습: due 카드 큐, 4단계 평가, Turbo Stream next-card swap
- [ ] Flip browse (빠른 훑어보기): 진도 미기록, 순서/셔플

**학습 진입점**
- [ ] `/decks` — hub. "오늘의 복습" hero(due 카운트) + 내 덱 목록(공식/클럽/개인 그룹)
- [ ] `/study` — 글로벌 큐 (모든 접근 가능 덱의 due 통합)
- [ ] `/decks/:id/study` — 덱별 학습
- [ ] 카드 평가: `POST /card_reviews` → Turbo Stream으로 다음 카드 swap

**카드 작성 UX**
- [ ] 단일 카드 폼 ("저장하고 다음" 키보드 연속 입력)
- [ ] Paste import: textarea + 카드 간/면 간 구분자 → 미리보기 → 일괄 저장
- [ ] 인라인 편집: 덱 상세 카드 표에서 Turbo Frame

**권한 (Pundit)**
- [ ] `DeckPolicy` — scope별 접근·수정·삭제 규칙
- [ ] `CardPolicy` — `DeckPolicy`에 위임
- [ ] `CardReviewPolicy` — `record.user == current_user`

**토너먼트 연결**
- [ ] `TournamentEventDeck` 조인 테이블 `(tournament_event_id, deck_id, position)`
- [ ] 매핑 권한: 해당 토너먼트의 club_manager + site_admin
- [ ] 후보 덱: 모든 공식 덱 + 매핑자 소속 클럽의 클럽 덱
- [ ] 설정 UI: `tournament_events/:id/edit`
- [ ] 노출 UI: `tournament_events/:id` show 상단 "📚 이 종목 학습하기" 카드

**통계 4종**
- [ ] Streak (연속 학습 일수, KST 자정 기준)
- [ ] 오늘의 현황 (학습 완료 / due 카운트)
- [ ] 덱별 마스터리 % (`interval_days >= 21` 카드 비율)
- [ ] 7일 due 예상 (CSS 막대 차트)

**알림 (인앱 배지만)**
- [ ] 네비 "낱말카드" 라벨 옆 due 카운트 배지
- [ ] Solid Cache 1시간 TTL, 학습/카드 변경 시 invalidate

**시드 콘텐츠 (출시 동시)**
- [ ] `db/seeds/flashcards.yml`에서 공식 덱 3종 로드:
  - "피클볼 기본 룰 30선"
  - "영어 콜아웃 & 용어"
  - "스코어링 시나리오 20"

**빈 상태 UX**
- [ ] `/decks` — 0 덱 사용자에게 시드 덱 hero + "내 덱 만들기" + "붙여넣기 가져오기" CTA
- [ ] 클럽 manage 페이지 manager onboarding nudge (1회, dismiss 가능)

**네비게이션**
- [ ] 유틸리티 dropdown에 "낱말카드" 추가 (포모도로 옆)

### Out of Scope

- 공개 UGC (개인 덱을 모든 사용자에게 공개) — 모더레이션 비용 과다, v2 검토
- 카드 타입 변종 (Cloze, 객관식, 오디오) — `card_type` enum 컬럼은 확장을 위해 남겨두되 v1은 `:basic`만
- 카드 텍스트 버전 관리 — ADR 0001에서 단일 Card 공유 결정, 버전 이력은 불필요
- 클럽 리더보드 / 뱃지 / 게임화 — 학습 동기보다 룰 습득이 우선, v2 검토
- 오디오 첨부, 코트 다이어그램 에디터 — 피클볼 특화 미디어, 요구사항 미검증
- 이메일 / Web push / Telegram 알림 — Solid Cache 배지로 충분, v2 검토
- 사용자별 타임존 설정 — KST 하드코딩 (기존 패턴 유지)
- CSV 업로드 — Paste import로 대체
- Soft delete — cascade hard delete (기존 패턴)
- Test/Match/Spell 게임 모드 — 기본 SRS 우선 검증 후
- Game session 연결 — 토너먼트 이벤트 연결까지만 v1 범위

## Context

**도메인 배경**: 피클볼 동호인은 영어 콜아웃, 더블 서브 순환, 키친 룰을 자주 혼동한다. 토너먼트/세션 중 룰 분쟁이 잦다. `CONTEXT.md`(레포 루트)에 전체 도메인 용어 정의가 있다.

**아키텍처 결정 (ADR 0001)**: Card를 fork 시 복사하지 않고 `CardReview` 조인 테이블로 사용자별 SRS 상태를 분리한다. admin이 카드 텍스트를 수정하면 모든 사용자에게 즉시 반영된다. 삭제 시 CardReview cascade. `docs/adr/0001-flashcard-cardreview-shared-cards.md` 참조.

**기존 인프라**:
- `ClubMembership` — `role` (member/manager), `status` (pending/approved/rejected/withdrawal_requested). Deck 권한 체크에 그대로 활용
- `TournamentEvent` — `discipline`, `scoring_format`, `status`. `TournamentEventDeck` 조인으로 확장
- `User.role` — `role_admin` = site_admin 권한
- 네비: 유틸리티 dropdown에 포모도로 등 기존 항목 있음. 동일 패턴 적용
- Pundit base policy (`ApplicationPolicy`) + 21개 기존 policy 파일 패턴 확립됨
- Solid Cache + Solid Queue 이미 사용 중

**시드 콘텐츠 정책**: 카드 텍스트는 AI 초안 작성 후 사람이 검토·승인 (룰 오류는 사람이 최종 확인 — 사람이 최종 권위).

## Constraints

- **Tech stack**: Rails 8.1, SQLite, Hotwire/Turbo Streams, Stimulus, Tailwind CSS 4, Propshaft + Import Maps — Node.js, Redis, React 없음
- **Testing**: RSpec (model + request + system). FactoryBot, Shoulda Matchers, Capybara. TDD Red→Green→Refactor
- **Security**: Brakeman 신규 경고 0. Pundit default-deny. `authorize` 모든 액션
- **DB**: 마이그레이션 가역(reversible). 인덱스 `(user_id, next_review_at)` 필수
- **타임존**: KST 하드코딩 (`config.time_zone = "Seoul"`)
- **i18n**: 한국어 하드코딩 (기존 패턴 유지, i18n yml 불사용)
- **알고리즘**: SM-2 Ruby 서비스 자작 (SRS gem 없음)
- **이미지**: ActiveStorage 구조는 만들되 S3 미설정 — UI 숨김으로 처리

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single Card + CardReview (ADR 0001) | fork 시 Card 복사 없이 조인 테이블로 SRS 상태 분리 — DB 폭발 방지, admin 수정 즉시 반영 | — Pending |
| SM-2 직접 구현 (gem 없음) | 4단계 평가 커스터마이징, 외부 의존 제거 | — Pending |
| 카드 타입 enum 컬럼 추가 (v1=basic) | v2 확장 대비 스키마 변경 최소화 | — Pending |
| Turbo Stream next-card swap (SRS 평가) | 페이지 전환 없는 즉각 반응 — Core Value 직결 | — Pending |
| Paste import (CSV 업로드 제외) | 브라우저만으로 대량 입력 가능, 서버 파싱 복잡도 제거 | — Pending |
| KST 하드코딩 (streak 기준) | 사용자별 타임존 설정 미구현 — 단순성 우선 | — Pending |
| TournamentEventDeck 조인 테이블 | 토너먼트 이벤트당 N개 덱 매핑, position 정렬 | — Pending |

---
*Last updated: 2026-05-30 — Phase 2 complete (Deck + Card CRUD, paste import, inline edit, gap closure)*
