---
status: partial
phase: 03-srs-learning-loop
source: [03-VERIFICATION.md]
started: 2026-05-30T09:33:00Z
updated: 2026-05-30T09:33:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Turbo Stream next-card swap 시각 확인
expected: 학습 세션 중 카드 평가 후 DOM에서 #study-card 영역이 Turbo Stream으로 교체되어 다음 카드가 부드럽게 표시된다
result: [pending]

### 2. 키보드 단축키 1/2/3/4 동작
expected: 학습 화면에서 키보드 1/2/3/4 누를 때 카드 flip → 해당 등급 자동 제출 정상 동작
result: [pending]

### 3. Browse 모드 Fisher-Yates 셔플 시각 확인
expected: /decks/:id/browse 접속 시 카드 순서가 무작위(셔플)이며 "셔플 중" 라벨이 표시된다
result: [pending]

### 4. 빈 덱 disabled 버튼 UX 확인
expected: 카드가 없는 덱의 show 페이지에서 '학습 시작' 버튼이 시각적으로 비활성화되고 "카드를 먼저 추가하세요" 힌트가 보인다
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
