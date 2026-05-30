# Phase 3: SRS Learning Loop - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 03-srs-learning-loop
**Areas discussed:** 카드 Flip + 평가 버튼 UX, Turbo Stream 다음 카드 전략, Browse mode 네비게이션, 글로벌 StudyController 덱 스코프

---

## 카드 Flip + 평가 버튼 UX

### 답 보기 트리거 방식

| Option | Description | Selected |
|--------|-------------|----------|
| "답 보기" 버튼 클릭 | 명시적 버튼, 모바일/데스크탑 동일 UX, 구현 단순 | ✓ |
| 카드 영역 전체 클릭/탭 | 직관적이나 실수 클릭 위험. Quizlet 스타일 | |
| CSS 3D flip 애니메이션 | 시각적으로 인상적이나 Stimulus 복잡도↑, 모바일 터치 튐 가능 | |

**User's choice:** "답 보기" 버튼 클릭

### 평가 버튼 위치

| Option | Description | Selected |
|--------|-------------|----------|
| 카드 바로 아래 (전체 폭 버튼) | 키보드 1/2/3/4와 자연스럽게 매핑, 현재 show.html.erb 구조에 맞음 | ✓ |
| 카드 하단 인라인 (카드 내부) | 카드 높이가 가변적 → 레이아웃 불안정 가능 | |
| 카드 위에 (상단 고정) | 인지 흐름 역방향. 비권장 | |

**User's choice:** 카드 바로 아래 (전체 폭 버튼)

### 답 보기 전 평가 버튼 상태

| Option | Description | Selected |
|--------|-------------|----------|
| 완전 숨김 (display: none) | 깔끔, Turbo Stream 리플레이스 시 초기화 고려 필요 | ✓ |
| 비활성화(disabled) + 흐리게 | 버튼 위치 미리 파악 가능, 레이아웃 점프 없음 | |

**User's choice:** 완전 숨김 (display: none)

### Flip 상태 관리

| Option | Description | Selected |
|--------|-------------|----------|
| Stimulus data-attribute (data-flipped) | study_session_controller 토글 → CSS show/hide. 서버 왕복 없음. 심플 | ✓ |
| Turbo Frame 리로드 | GET /decks/:id/study?reveal=true → 서버 back 포함 partial 반환. 불필요한 round-trip | |

**User's choice:** Stimulus data-attribute (data-flipped)

---

## Turbo Stream 다음 카드 전략

### POST /card_reviews 후 다음 카드 스왑

| Option | Description | Selected |
|--------|-------------|----------|
| 서버가 다음 카드 계산 + Turbo Stream swap | 서버 stateless, 코드 단순, 새로고침 후에도 올바른 상태 | ✓ |
| 클라이언트 큐 (Stimulus 카드 IDs 보유) | 서버 round-trip 감소지만 클라이언트 로직↑, 카드 내용 선포로드 필요 | |

**User's choice:** 서버가 다음 카드 계산 + Turbo Stream swap

### 세션 완료 감지

| Option | Description | Selected |
|--------|-------------|----------|
| 서버가 빈 partial을 Turbo Stream으로 반환 (complete 뷰 렌더) | complete.html.erb 재활용, 일관성 | ✓ |
| 서버가 JSON {done: true} → Stimulus location.href 변경 | 클라이언트 사이드 로직 증가. 불필요 | |

**User's choice:** 서버가 빈 partial을 Turbo Stream으로 반환

### deck_id 전달 방식

| Option | Description | Selected |
|--------|-------------|----------|
| card_review[deck_id] hidden field (form param) | form에 hidden input 포함. Controller에서 permit | ✓ |
| card로부터 deck 연산 (card.deck_id) | card_id가 있으면 deck 식별 가능, hidden field 불필요. 소소한 추가 쿼리 1건 | |

**User's choice:** card_review[deck_id] hidden field

### SM-2 로직 위치

| Option | Description | Selected |
|--------|-------------|----------|
| SubmitReviewService 별도 서비스 (ROADMAP 명시) | 컨트롤러 슬림, 테스트 독립성 | ✓ |
| 컨트롤러 인라인 | CLAUDE.md 원칙 위반 (Skinny Controller) | |

**User's choice:** SubmitReviewService 별도 서비스

---

## Browse Mode 네비게이션

### 카드 네비게이션 구현 방식

| Option | Description | Selected |
|--------|-------------|----------|
| 클라이언트 사이드 전체 로드 | 서버 round-trip 0, 셔플도 클라이언트에서 수행, 카드 수 적어서 실현 가능 | ✓ |
| 서버 사이드 한 장씩 fetch | 쇼파로운 와이어링, URL 파라미터 브라우저 백 가능 | |

**User's choice:** 클라이언트 사이드 전체 로드

### Browse flip

| Option | Description | Selected |
|--------|-------------|----------|
| 스터디 모드와 동일한 "답 보기" 버튼 | 일관성 유지 | ✓ |
| 카드 영역 클릭으로 flip | browse 개념이 직관적이나 study와 다른 UX | |

**User's choice:** "답 보기" 버튼 (study와 동일)

### 셔플

| Option | Description | Selected |
|--------|-------------|----------|
| 페이지 상단 토글 버튼, Stimulus Fisher-Yates 셔플 | 클라이언트 사이드, 서버 요청 없음 | ✓ |
| 서버에서 랜덤 시드 + order 정렬 | URL에 seed 파라미터 포함, 새로고침해도 순서 유지. 과가산성 | |

**User's choice:** Stimulus Fisher-Yates 셔플

### Browse 진입 URL

| Option | Description | Selected |
|--------|-------------|----------|
| GET /decks/:id/browse (라우트 독립, 전체 로드) | Decks::BrowsesController 독립, 브라우저 뒤로가기 가능 | ✓ |
| 덱 상세페이지 하단 링크로 browse 모드 진입 | 동일 URL에서 browse 모드 토글. 라우트 분리 안 됨 | |

**User's choice:** GET /decks/:id/browse 독립 라우트

---

## 글로벌 StudyController 덱 스코프

### 접근 가능 덱 스코프

| Option | Description | Selected |
|--------|-------------|----------|
| Personal(owner=me) + Official 명시적 OR 스코프 | policy_scope 없이 안전. Phase 4에서 DeckPolicy::Scope로 교체 예정 | ✓ |
| 유저 관련 덱만 (자신 personal만) | REQUIREMENTS STUDY-02 위반 (글로벌 큐는 모든 접근 가능 덱) | |

**User's choice:** Personal + Official 명시적 OR 스코프

### 글로벌 큐 쿼리 클래스

| Option | Description | Selected |
|--------|-------------|----------|
| GlobalStudyQueueQuery 별도 클래스 (user:만 받음) | 글로벌과 덱별 큐 로직이 달라서 분리가 명확 | ✓ |
| StudyQueueQuery에 deck: nil 옵션 추가 | 하나의 클래스로 유지. 조건분기 복잡도 증가 가능 | |

**User's choice:** GlobalStudyQueueQuery 별도 클래스

### StudyController 라우트 구조

| Option | Description | Selected |
|--------|-------------|----------|
| StudyController < ApplicationController (네임스페이스 없이) | get '/study'. 덱별 controller와 독립. 관문 없음 | ✓ |
| Decks::StudiesController에서 deck 없이 처리 | 컨트롤러 하나이나 로직 분기 복잡 | |

**User's choice:** StudyController < ApplicationController

### 글로벌 큐 빈 상태

| Option | Description | Selected |
|--------|-------------|----------|
| 덱별과 동일한 complete 뷰 렌더 ("오늘 학습 완료") | 일관성. @deck 없으므로 링크 텍스트만 조정 | ✓ |
| /decks로 리다이렉트 | UX 단순하지만 덱별 완료와 일관성 없음 | |

**User's choice:** complete 뷰 렌더 (덱별과 동일 패턴)

---

## Claude's Discretion

- Stimulus controller 파일명 (study_session_controller.js vs study_controller.js 등)
- Browse 카드 데이터 직렬화 포맷 (JSON `data-value` vs data-attribute per card)
- `SubmitReviewService` Result 구조 (`Struct` / `OpenStruct` / `Data.define`)
- 키보드 단축키 힌트 UI 구현 방식 (Phase 3 범위이나 구현 세부 사항은 Claude 재량)

## Deferred Ideas

- Club deck in global study queue → Phase 4 (DeckPolicy::Scope 교체 후)
- Due-count badge on nav → Phase 5 (Solid Cache + invalidation)
- Streak / mastery / today stats → Phase 5
- Tournament event 학습 CTA → Phase 5
- Per-day new card limit 설정 UI → v1 LIMIT 10 하드코딩
