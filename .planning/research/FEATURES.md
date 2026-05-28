# Feature Research

**Domain:** SRS (Spaced Repetition System) 플래시카드 — 피클볼 룰·용어 학습
**Researched:** 2026-05-29
**Confidence:** HIGH (PROJECT.md 기반 직접 분석, 도메인 요구사항 명확)

---

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| 카드 뒤집기 (flip) | 플래시카드의 기본 인터랙션 | LOW | Stimulus controller로 CSS transform. browse 모드에 포함 |
| 덱 목록 & 상세 페이지 | 학습 콘텐츠 탐색의 시작점 | LOW | `/decks` hub. 공식/클럽/개인 그룹 분류 |
| SRS 학습 세션 | "공부했다"는 느낌의 핵심 — 없으면 앱이 아닌 카드 뷰어 | MEDIUM | due 큐 + 4단계 평가 + Turbo Stream next-card swap |
| 카드 생성 (단일 폼) | 본인 덱에 카드를 추가할 수 없으면 무용지물 | LOW | "저장하고 다음" 패턴, 키보드 연속 입력 |
| 덱 생성 (personal) | 사용자가 자기 학습 세트를 만들 수 있어야 함 | LOW | scope=personal, 비공개 기본값 |
| 오늘의 복습 카운트 | 학습 동기 부여 — 배지/카운터 없으면 앱을 열 이유가 없음 | LOW | Solid Cache 1시간 TTL, 배지로 표시 |
| 학습 진도 저장 | 새로고침 후에도 어디까지 했는지 알 수 있어야 함 | MEDIUM | CardReview 테이블, SM-2 상태 지속 |
| 권한 구분 (읽기/쓰기) | 남의 덱을 임의 수정할 수 없어야 함 | MEDIUM | Pundit DeckPolicy, default-deny |
| 빈 상태 UX | 첫 사용자가 뭘 해야 하는지 모르면 이탈 | LOW | 시드 덱 hero + CTA 버튼 2개 |

### Differentiators (Competitive Advantage)

Quizlet, Anki 등 범용 SRS와 달리 PBPlayground 플랫폼에 내재화된 피클볼 특화 기능들.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| 토너먼트 이벤트 연결 | 대회 전날 "이 종목 학습하기" CTA → 즉각적 학습 동기 | MEDIUM | TournamentEventDeck 조인 테이블. 이벤트 show 페이지 상단 노출 |
| Club 덱 (클럽 단위 공유) | 클럽 멤버 전용 콘텐츠 — 클럽 매니저가 룰 Q&A 카드 만들어 배포 | MEDIUM | scope=club, ClubMembership approved 체크. 모더레이션 토글 |
| 공식 시드 덱 3종 (즉시 학습 가능) | 가입 즉시 콘텐츠가 있는 상태 — 빈 앱 신뢰도 문제 해소 | LOW | "피클볼 기본 룰 30선", "영어 콜아웃 & 용어", "스코어링 시나리오 20" |
| Fork (공식→개인 복제) | 공식 덱을 베이스로 내 메모를 추가하는 개인화 학습 | LOW | Card 복사 없이 CardReview만 분리 (ADR 0001) |
| 글로벌 학습 큐 (`/study`) | 덱 선택 없이 "오늘 할 것 전부" 한방 학습 | LOW | 모든 접근 가능 덱의 due 카드 통합 |
| 통계 4종 (streak, 마스터리, 7일 예상) | 숙달 가시화 — "내가 얼마나 알고 있나" 확인 | MEDIUM | 별도 집계 쿼리. 7일 예상은 CSS 막대 차트 |
| Paste import | 구분자 기반 대량 카드 입력 — CSV 서버 파싱 없이 브라우저에서 처리 | MEDIUM | textarea → 파싱 미리보기 → 일괄 저장. Stimulus controller |
| 클럽 관리 페이지 onboarding nudge | 매니저가 클럽 덱을 만들도록 유도 (1회, dismiss 가능) | LOW | 기존 Club manage 페이지에 조건부 배너 |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| 공개 UGC (개인 덱 전체 공개) | 콘텐츠 다양성 증대 기대 | 모더레이션 비용 과다. 스팸/오류 룰 카드가 신뢰도를 무너뜨림 | official 덱 + club 덱으로 충분한 공유 범위 확보 |
| 카드 타입 변종 (cloze, 객관식) | 학습 다양성 | v1 SM-2 검증 전에 UI 복잡도 폭발. 데이터 모델도 달라짐 | card_type enum 컬럼만 미리 만들어 두고 v2에서 확장 |
| 이메일/푸시 알림 | "복습 시간됐어요" 리마인더 | Rails 8 + Solid Queue에서 구현 가능하지만, 알림 피로도 높음. 인앱 배지로 충분히 검증 먼저 | 네비 due 카운트 배지로 대체 |
| 게임화 (리더보드, 뱃지) | 경쟁 동기 부여 | 룰 습득이 목표 — 경쟁 구조는 "빨리 넘기기" 부정행위 유도 | streak + 마스터리 % 통계로 자기 발전 지표 제공 |
| 카드 텍스트 버전 관리 | admin 수정 이력 추적 | ADR 0001 위반. Card 공유 모델에서 버전 이력은 CardReview와 충돌. DB 복잡도 과다 | admin이 신중하게 수정. 시드 콘텐츠는 사람이 직접 작성으로 품질 보장 |
| 사용자별 타임존 설정 | 해외 사용자 대응 | KST 하드코딩 기존 패턴 이탈. streak 기준 복잡성 증가 | KST 하드코딩 유지 (국내 동호회 서비스) |
| CSV 업로드 | 스프레드시트에서 직접 임포트 | 서버 파싱·인코딩 에러 처리 복잡. 보안 surface 증가 | Paste import로 브라우저 파싱 대체 (동일 결과) |
| Soft delete | 실수로 삭제한 카드 복구 | 기존 패턴 불일치. CardReview orphan 처리 복잡 | Cascade hard delete (기존 패턴 유지) |

---

## Feature Dependencies

```
[SM-2 서비스 (Ruby)]
    └──required by──> [SRS 학습 세션]
                          └──required by──> [CardReview 통계]
                                                └──required by──> [Streak]
                                                └──required by──> [마스터리 %]
                                                └──required by──> [7일 due 예상]

[Deck 모델 (3-tier scope)]
    └──required by──> [Card 모델]
                          └──required by──> [CardReview]
                          └──required by──> [Paste import]
                          └──required by──> [Fork]

[DeckPolicy (Pundit)]
    └──required by──> [CardPolicy]
    └──required by──> [Club 덱 모더레이션]

[TournamentEvent (기존)]
    └──extended by──> [TournamentEventDeck 조인]
                          └──required by──> [토너먼트 이벤트 연결 UI]

[ClubMembership (기존)]
    └──referenced by──> [Club 덱 접근 권한]

[Solid Cache (기존)]
    └──used by──> [due 카운트 배지 캐싱]
```

### Dependency Notes

- **SM-2 서비스는 SRS 학습 세션의 전제**: 서비스 없이 평가 버튼만 있으면 아무 효과 없음. SM-2 먼저 구현 → 학습 세션 연결.
- **Deck가 Card의 전제**: Card는 반드시 Deck에 속함. Deck 모델·마이그레이션이 먼저.
- **Fork는 Card 공유 모델(ADR 0001) 위에서만 작동**: Card 복사 없이 CardReview 분리. ADR 0001 구현 후에 fork 로직 추가.
- **토너먼트 연결은 핵심 SRS 기능과 독립적**: 기존 TournamentEvent에 조인 테이블만 추가. 핵심 학습 플로우 완성 후 연결 가능.
- **통계는 CardReview 데이터 축적 후 의미 있음**: streak/마스터리는 학습 세션이 동작한 다음에 값이 생김. 구조는 먼저 만들되 테스트 데이터로 검증.

---

## MVP Definition

### Launch With (v1)

이것들이 없으면 "플래시카드 앱"이 아닌 카드 뷰어에 불과.

- [ ] **Deck 모델 (3-tier)** — 공식/클럽/개인 구분 없이는 권한 모델 자체가 없음
- [ ] **Card 모델 + 기본 CRUD** — 카드가 없으면 아무것도 없음
- [ ] **SM-2 Ruby 서비스** — Core Value의 엔진. 없으면 SRS가 아닌 단순 뒤집기
- [ ] **SRS 학습 세션 (Turbo Stream next-card)** — Core Value 직결. 끊기면 무의미
- [ ] **CardReview (SRS 상태 저장)** — 학습 결과가 저장 안 되면 내일 다시 처음부터
- [ ] **4단계 평가 UI** — 다시/어려움/보통/쉬움 버튼
- [ ] **Flip browse 모드** — 가볍게 훑어보기. SRS 외 진입 경로
- [ ] **공식 시드 덱 3종** — 첫 사용자 빈 상태 방지. 출시 동시 필수
- [ ] **DeckPolicy + CardPolicy (Pundit)** — 보안 기본기. 없으면 출시 불가
- [ ] **due 카운트 배지 (네비)** — 앱을 다시 열 이유. TTL 캐싱으로 부하 없음
- [ ] **빈 상태 UX** — 첫 사용자 이탈 방지. 시드 덱 hero + CTA
- [ ] **네비게이션 진입점** — 유틸리티 dropdown 추가 없으면 기능 발견 불가

### Add After Validation (v1.x)

핵심이 동작 확인 후 추가.

- [ ] **통계 4종 (streak, 마스터리, 7일 예상)** — CardReview 데이터가 쌓인 후 의미 있음. 구조는 v1에 포함하되 UI 완성도는 v1.x
- [ ] **클럽 manage 페이지 onboarding nudge** — 초기 클럽 덱 채택률 확인 후 필요성 검증
- [ ] **Paste import** — 단일 카드 폼으로 충분한지 먼저 확인. 대량 입력 수요 검증 후 추가

### Future Consideration (v2+)

- [ ] **카드 타입 변종 (cloze, 객관식)** — card_type enum 컬럼만 미리 확보. 수요 검증 후
- [ ] **공개 UGC** — 모더레이션 체계 구축 필요. 커뮤니티 규모 확인 후
- [ ] **이메일/푸시 알림** — 인앱 배지 효과 측정 후 추가 채널 검토
- [ ] **게임화 (리더보드, 뱃지)** — 기본 학습 루프 정착 후 동기 부여 강화
- [ ] **카드 타입 오디오/다이어그램** — 피클볼 특화 미디어, 요구사항 미검증

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| SM-2 Ruby 서비스 | HIGH | MEDIUM | P1 |
| SRS 학습 세션 + Turbo Stream | HIGH | MEDIUM | P1 |
| CardReview (SRS 상태) | HIGH | LOW | P1 |
| Deck 3-tier 모델 | HIGH | MEDIUM | P1 |
| Card CRUD | HIGH | LOW | P1 |
| 공식 시드 덱 3종 | HIGH | LOW | P1 |
| DeckPolicy/CardPolicy | HIGH | LOW | P1 |
| due 배지 (네비) | MEDIUM | LOW | P1 |
| Flip browse 모드 | MEDIUM | LOW | P1 |
| 빈 상태 UX | MEDIUM | LOW | P1 |
| 네비 진입점 | MEDIUM | LOW | P1 |
| Fork (공식→개인) | MEDIUM | LOW | P2 |
| 토너먼트 이벤트 연결 | MEDIUM | MEDIUM | P2 |
| Paste import | MEDIUM | MEDIUM | P2 |
| 통계 4종 | MEDIUM | MEDIUM | P2 |
| Club 덱 모더레이션 featured 토글 | LOW | LOW | P2 |
| onboarding nudge | LOW | LOW | P3 |
| 카드 타입 변종 | LOW | HIGH | P3 |
| 이메일/푸시 알림 | LOW | MEDIUM | P3 |
| 게임화 | LOW | HIGH | P3 |

**Priority key:**
- P1: 출시 필수 (v1)
- P2: 핵심 검증 후 추가 (v1.x)
- P3: v2+ 검토

---

## Competitor Feature Analysis

SRS 플래시카드 도메인 주요 경쟁자와 차별점.

| Feature | Quizlet | Anki | 우리 접근 |
|---------|---------|------|-----------|
| SRS 알고리즘 | 자체 (단순) | SM-2 기반 오픈소스 | SM-2 Ruby 자작, 4단계 평가 |
| 콘텐츠 공개 범위 | 전체 공개 UGC | 개인+공개 덱 | official + club + personal (UGC 제한) |
| 플랫폼 통합 | 독립 앱 | 독립 앱 | PBPlayground 내장 (토너먼트·클럽 연결) |
| 오프라인 지원 | 유료 | 앱 기본 지원 | 미지원 (v1 범위 외) |
| 카드 타입 | 다양 (cloze, 객관식 등) | 매우 다양 | v1=basic only (enum으로 확장 준비) |
| 대량 입력 | CSV 업로드 | 텍스트 파일 | Paste import (구분자 방식) |
| 학습 통계 | 히트맵, 정확도 | 분산 그래프 | streak + 마스터리 % + 7일 예상 (도메인 특화) |
| 클럽/그룹 기능 | 클래스룸 (유료) | 없음 | Club 덱 (ClubMembership 기반, 무료) |
| 도메인 특화 | 범용 | 범용 | 피클볼 룰·용어 특화 시드 콘텐츠 |

**핵심 차별화 포인트**: 범용 SRS 앱들은 플랫폼 컨텍스트가 없다. PBPlayground는 토너먼트 이벤트·클럽 멤버십과 직접 연결되어 "오늘 대회 있는데 이 종목 룰 공부해" 같은 자연스러운 학습 동기를 만든다. Quizlet에서는 절대 불가능한 플로우.

---

## Sources

- PROJECT.md (직접 분석) — 요구사항, Out of Scope, Key Decisions 섹션
- ADR 0001 (docs/adr/0001-flashcard-cardreview-shared-cards.md) — Card 공유 모델 결정
- 기존 인프라 분석 (ClubMembership, TournamentEvent, Pundit, Solid Cache) — 통합 포인트
- SRS 도메인 지식 (SM-2 알고리즘, Anki/Quizlet 비교) — HIGH confidence (공개 알고리즘)

---
*Feature research for: 낱말카드 (Flashcards) v1 — 피클볼 SRS 플래시카드*
*Researched: 2026-05-29*
