# CLAUDE.md

이 파일은 Claude Code가 이 Obsidian vault에서 일할 때 따르는 운영 스키마입니다.

목표는 개인 메모장이 아니라, 회사 실무에서 여러 AI 에이전트와 사람이 같은 업무 맥락을 공유하고 이어받을 수 있는 안정적인 비즈니스 프로세스를 만드는 것입니다.

## Operating Model

이 vault는 세 층으로 운영합니다.

1. `AI-Sessions/raw/`: 불변 원천 자료입니다. 회의록, 고객 인터뷰, 정책 문서, 화면 캡처 설명, 외부 자료 원문처럼 나중에 근거로 다시 확인해야 하는 자료를 둡니다.
2. `AI-Sessions/wiki/`: raw와 대화에서 얻은 정보를 업무 지식으로 컴파일한 공간입니다. 에이전트가 작성하고 유지보수하며, 사람과 동료 에이전트가 읽습니다.
3. `CLAUDE.md`, `AGENTS.md`, `index.md`, `log.md`: 운영 규칙과 탐색 장치입니다. 이 파일들은 wiki가 산만한 메모장이 되지 않게 만드는 프로세스입니다.

## Core Rules

1. 작업 시작 전 `index.md`를 읽어 전체 구조를 파악합니다.
2. 이어서 `log.md`의 최근 항목을 확인해 직전 작업 흐름을 복원합니다.
3. 관련 프로젝트가 있으면 `AI-Sessions/wiki/projects/`와 연결된 decision, error, design, dev-task 문서를 먼저 확인합니다.
4. `AI-Sessions/raw/` 안의 원본 자료는 수정하거나 삭제하지 않습니다.
5. raw 자료를 바탕으로 요약, 판단, 결정, 기획 자료를 만들 때는 `AI-Sessions/wiki/` 아래에 별도 문서를 만듭니다.
6. 세션 인수인계가 필요할 때만 `AI-Sessions/conversations/`에 handoff 문서를 저장합니다. 대화 전체를 무분별하게 덤프하지 않습니다.
7. 중요한 wiki 문서를 만들거나 갱신한 뒤에는 반드시 `index.md`와 `log.md`를 함께 갱신합니다.
8. 사용자가 명시적으로 원하지 않는 한 민감정보, 인증 정보, 비밀번호, 고객 개인정보를 저장하지 않습니다.

## Command Keywords

사람이 읽는 가이드라인은 한국어로 작성합니다.

에이전트가 실행하는 명령 키워드와 자동화 트리거는 영어로 고정합니다.

- `save`: 현재 작업에서 재사용 가치가 있는 지식을 wiki 또는 conversations에 저장합니다.
- `ingest`: raw 자료를 읽고 wiki 문서로 컴파일합니다.
- `query`: index, log, wiki를 검색해 이전 맥락을 복원하고 답변합니다.
- `lint`: vault 구조, 링크, 저장 규칙, 민감정보 위험을 점검합니다.

## Save Filter

무분별한 저장은 업무 맥락을 오염시킵니다. `save`, `ingest`, `query` 결과 저장, handoff 저장 전에 아래 5가지 필터를 반드시 적용합니다.

1. 향후 실무에 반복해서 재사용될 데이터인가?
2. 다른 에이전트나 동료가 프로젝트를 이어받기 위해 반드시 읽어야 하는가?
3. 의사결정의 근거와 결정권자를 나중에 추적할 필요가 있는가?
4. 실패한 방식이라 다시 시도하면 안 되는 리스크 정보인가?
5. 팀 전체가 맞추어야 하는 공통 규칙이나 디자인 가이드인가?

이 조건 중 하나도 만족하지 않는 일회성 답변, 감상, 사소한 표현 변경, 임시 계산 결과는 wiki에 저장하지 않습니다. 저장하지 않을 때는 "저장 필터를 통과하지 못해 저장하지 않음"이라고 짧게 설명합니다.

## Folder Responsibilities

- `AI-Sessions/raw/`: 원천 자료. 에이전트는 읽기만 합니다. 새 원천 자료 추가는 가능하지만 기존 raw 파일은 수정하지 않습니다.
- `AI-Sessions/wiki/sources/`: raw 자료별 요약, 출처, 신뢰도, 주요 인용 위치, 연결 문서.
- `AI-Sessions/wiki/concepts/`: 반복 사용되는 업무 개념, 용어, 프레임워크.
- `AI-Sessions/wiki/decisions/`: 결정 내용, 결정권자, 근거, 대안, 영향 범위.
- `AI-Sessions/wiki/errors/`: 실패한 시도, 재시도 금지 조건, 위험 신호, 복구 방법.
- `AI-Sessions/wiki/projects/`: 프로젝트별 목표, 상태, 이해관계자, 현재 맥락, 연결 문서.
- `AI-Sessions/wiki/design/`: 팀 공통 디자인 원칙, IA, 화면 설계 가이드, UX 규칙.
- `AI-Sessions/wiki/dev-tasks/`: 개발 작업 단위, 의존성, 구현 메모, 검증 결과.
- `AI-Sessions/conversations/`: 다음 세션이 이어받아야 할 handoff. 저장 필터를 통과한 경우에만 사용합니다.

## Command Workflows

### `save`

1. 저장하려는 내용을 5가지 필터에 대조합니다.
2. 저장할 가치가 있으면 적절한 wiki 카테고리나 conversations 위치를 선택합니다.
3. 새 문서에는 근거 링크, 관련 raw/source, 결정권자나 담당자를 가능한 한 명시합니다.
4. 관련 문서에 Obsidian wikilink를 추가합니다.
5. `index.md`에 새 문서 링크와 한 줄 설명을 추가합니다.
6. `log.md`에 append-only 형식으로 작업을 기록합니다.

### `ingest`

1. raw 파일을 읽되 수정하지 않습니다.
2. source 문서를 만들고 원천 파일 경로와 핵심 내용을 요약합니다.
3. 반복 개념은 concepts, 결정은 decisions, 실패/리스크는 errors, 프로젝트 맥락은 projects에 반영합니다.
4. 새 정보가 기존 wiki와 충돌하면 기존 문서를 조용히 덮지 말고 contradiction 또는 superseded 관계를 명시합니다.
5. `index.md`와 `log.md`를 갱신합니다.

### `query`

1. `index.md`를 먼저 읽어 후보 문서를 찾습니다.
2. `log.md`에서 최근 변경 흐름을 확인합니다.
3. 관련 wiki 문서를 읽고, 필요한 경우 raw/source까지 추적합니다.
4. 답변에는 근거 문서를 명시합니다.
5. 질문 과정에서 재사용 가치가 큰 분석이 생기면 사용자에게 저장 여부를 확인하거나 `save` 규칙에 따라 저장합니다.

### `lint`

1. 필수 폴더와 `.gitkeep` 존재 여부를 확인합니다.
2. raw 파일이 수정되었거나 wiki에 원본 자료가 섞였는지 확인합니다.
3. index 누락, log 누락, 끊어진 wikilink, orphan 문서를 점검합니다.
4. 저장 필터를 통과하지 못한 일회성 정보가 wiki에 있는지 확인합니다.
5. 민감정보와 고객 개인정보 위험을 점검합니다.

## Document Format

새 wiki 문서는 가능하면 아래 형식을 따릅니다.

```markdown
---
type: decision | source | concept | error | project | design | dev-task | handoff
date: YYYY-MM-DD
status: draft | active | superseded
owner: person-or-team
source: raw-or-wiki-link
---

# 제목

## Summary

## Context

## Details

## Decisions

## Risks

## Links
```

필요 없는 섹션은 생략할 수 있지만, decision 문서는 결정권자와 결정 근거를, error 문서는 다시 시도하면 안 되는 조건을 반드시 남깁니다.

## Index And Log Rules

- `index.md`는 content-oriented 지도입니다. 모든 중요한 wiki 문서는 카테고리별로 링크와 한 줄 설명을 남깁니다.
- `log.md`는 chronological 기록입니다. append-only로 유지하고, 항목 제목은 `## [YYYY-MM-DD HH:mm] command | summary` 형식을 씁니다.
- `index.md`는 탐색을 위한 현재 지도이고, `log.md`는 시간순 감사 추적입니다. 둘 중 하나로 다른 하나를 대체하지 않습니다.

## Completion Report

작업이 끝나면 다음을 보고합니다.

- 읽은 주요 파일
- 생성하거나 수정한 파일
- 저장 필터 적용 결과
- 갱신한 index/log 항목
- 다음 세션에서 먼저 볼 문서
