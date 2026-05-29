---
phase: 02-deck-card-crud
created: 2026-05-29
---

# Phase 2 Discussion Log

이 문서는 인간 참조용이며 downstream 에이전트(연구/계획/실행)는 `02-CONTEXT.md`만 읽습니다.

## Gray Areas 선택 (multiSelect)

질문: Phase 2에서 논의할 영역을 모두 선택하세요 (구현 세부 결정 필요)
사용자 선택: **4개 모두 선택**
- 단일 카드 폼 키보드 UX
- Paste import UX + 안전
- /decks hub 레이아웃
- 인라인 편집 상호작용

## 핵심 결정 (라운드 1)

### Q1: 단일 카드 폼 — "저장하고 다음" 트리거?

옵션:
- Cmd+Enter (추천) ← **선택**
- Enter 단독 저장+다음
- 명시적 버튼 + Shift+Enter

이유: Enter 단독은 멀티라인 back 카드를 작성할 수 없게 만들어 우회 트리거 필요. Cmd+Enter는 데스크탑 표준이고 textarea의 줄바꿈을 보존.

### Q2: Paste import — 구분자 선택 방식?

옵션:
- 자동 감지 + 명시적 확인 (추천) ← **선택**
- 라디오버튼 명시 선택
- 고정 탭 구분자만

이유: 자동 감지로 첫 클릭 제거, 명시적 확인으로 잘못된 감지 방지, 수동 오버라이드로 엣지 케이스 처리.

### Q3: /decks hub — 3-tier 그룹화 방식?

옵션:
- 섹션 헤더 + 단일 스크롤 (추천) ← **선택**
- 탭 전환
- 아코디언

이유: 단일 페이지 한눈에 보기 + 탭/아코디언 클릭 부담 제거. Phase 5 hero 자리 확보 자연스러움.

### Q4: 인라인 카드 편집 — 트리거 + 저장 방식?

옵션:
- 행 전체 클릭 → 편집 모드 + 명시 저장 (추천) ← **선택**
- 셀 더블클릭 + blur 저장
- 명시 "수정" 버튼 + 모달/Drawer

이유: 행 클릭은 큰 히트박스(실수 방지), 명시 저장은 실수 변경 방지. Escape 취소로 빠른 빠져나오기.

## 엣지 케이스 결정 (라운드 2)

### Q5: 0 덱 상태 사용자가 /decks 진입 시 빈 상태 UX?

옵션:
- 온보딩: 공식 덱 hero + 2 CTA (추천) ← **선택**
- 단일 CTA + 공식 덱 섹션은 상설적 노출
- 완전 빈 화면 + 공식 덱 링크

이유: 사용자가 "왜 낱말카드인가" 즉시 학습 + 두 경로(create / paste) 모두 발견 가능.

### Q6: 이미지 첨부 필드 UI — v1 표시 여부?

옵션:
- 완전 숨김 + form params 차단 (추천, ROADMAP 점수 조건) ← **선택**
- "공사중" 표시 + 입력 차단
- 온/오프 토글 + 실험적 메뉴에서만 노출

이유: ROADMAP success criterion #8 "이미지 첨부 필드가 form params에 노출되지 않음" 강제 충족 + v1 가벼움 유지.

## 사용자가 제시하지 않은 결정 (Claude 재량 / Researcher가 권장안 제시)

`02-CONTEXT.md` `<open_questions>` 섹션 참조:
1. Paste import 트랜잭션 max card count
2. /decks/:id/study 진입 버튼 (Phase 3에서 도입 — 완전 비노출 vs placeholder)
3. 모바일 Cmd+Enter 대체 트리거
4. Empty 클럽 섹션 정확한 트리거

## Deferred Ideas

CONTEXT.md `<deferred>` 섹션 참조:
- 이미지 업로드 UX (v1 영구 숨김)
- Fork 버튼 UI → Phase 4
- 클럽 덱 생성 UX → Phase 4
- 공식 덱 모더레이션 UI → Phase 4
- Featured toggle → Phase 4
- 학습 시작 버튼 → Phase 3
- Due-count badge / streak / mastery → Phase 5
- 카드 정렬/필터 → Phase 5 또는 미루기
