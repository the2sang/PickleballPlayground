---
status: approved
phase: 02-deck-card-crud
source: [02-VERIFICATION.md]
started: 2026-05-30T08:00:00Z
updated: 2026-05-30T09:00:00Z
---

## Current Test

[user approved — browser testing deferred]

## Tests

### 1. Cmd+Enter 저장 후 autofocus 확인
expected: 카드 추가 폼에서 Cmd+Enter(Mac) / Ctrl+Enter(Win)로 저장 후 front 입력란에 자동 포커스됨
result: [pending]

### 2. 카드 행 클릭 → Turbo Frame 인라인 편집 전환
expected: 카드 행의 "편집" 버튼 클릭 시 Turbo Frame이 편집 폼으로 교체되고, 저장/취소 후 read-only 행으로 복귀함
result: [pending]

### 3. Escape 키 → cancelTarget.click() 동작 확인 (WR-01)
expected: 인라인 편집 폼에서 Escape 키 누르면 취소 링크가 클릭되어 read-only 카드 행으로 즉시 복귀함 (전체 페이지 reload 없이)
result: [pending]

### 4. paste_import_controller 구분자 자동 감지
expected: 텍스트 붙여넣기 시 탭/쉼표/세미콜론 구분자가 자동 감지되어 미리보기에 반영됨
result: [pending]

### 5. /decks 3섹션 레이아웃 시각적 확인
expected: /decks 화면에 내 덱 목록, 공개 덱, 빈 상태 hero 3개 섹션이 올바르게 렌더링됨
result: [pending]

### 6. 빈 상태 hero + WR-02 CTA UX 확인
expected: 덱이 없을 때 hero CTA 레이블과 실제 링크 동작이 의도한 대로 작동함 (Decision #5 준수)
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
