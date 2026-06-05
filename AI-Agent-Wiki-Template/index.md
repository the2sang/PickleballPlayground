# AI Agent Wiki Index

이 문서는 vault 전체의 content-oriented 지도입니다.

에이전트는 `query`를 시작할 때 이 문서를 먼저 읽고, 중요한 wiki 문서를 만들거나 갱신한 뒤 이 문서에 링크와 한 줄 설명을 추가해야 합니다.

## Start Here

- [[START_HERE]]: 첫 실행 프롬프트와 사용 순서
- [[README]]: 템플릿 목적, 설치, 폴더 구조
- [[CLAUDE]]: Claude Code용 운영 스키마
- [[AGENTS]]: Codex 및 기타 에이전트용 운영 스키마
- [[TEMPLATE_MANIFEST]]: 배포 시 포함되어야 하는 필수 파일과 폴더
- [[log]]: 시간순 작업 로그

## Operating Model

- `AI-Sessions/raw/`: 불변 원천 자료. 에이전트는 기존 raw 파일을 수정하지 않습니다.
- `AI-Sessions/wiki/`: 에이전트가 유지하는 컴파일된 업무 지식.
- `AI-Sessions/conversations/`: 다음 세션이 이어받아야 하는 handoff.
- `index.md`: 현재 지식 지형을 보여주는 지도.
- `log.md`: 시간순 작업 감사 기록.

## Command Map

- `save`: 저장 필터를 통과한 업무 지식을 wiki 또는 conversations에 저장합니다.
- `ingest`: raw 자료를 source 문서로 요약하고 관련 wiki 문서에 통합합니다.
- `query`: index, log, wiki를 읽고 이전 맥락을 복원합니다.
- `lint`: 구조, 링크, 저장 규칙, 민감정보 위험을 점검합니다.

## Save Filter

아래 조건 중 하나 이상을 만족할 때만 wiki 또는 conversations에 저장합니다.

1. 향후 실무에 반복해서 재사용될 데이터
2. 다른 에이전트나 동료의 인수인계에 필요한 정보
3. 의사결정의 근거와 결정권자 추적이 필요한 정보
4. 다시 시도하면 안 되는 실패나 리스크 정보
5. 팀 전체가 맞추어야 하는 공통 규칙이나 디자인 가이드

## Vault Structure

- `AI-Sessions/raw/`: 수정하지 않는 1차 자료
- `AI-Sessions/conversations/`: 세션 인수인계
- `AI-Sessions/wiki/sources/`: raw 자료 요약과 출처 맥락
- `AI-Sessions/wiki/concepts/`: 반복 사용 개념과 용어
- `AI-Sessions/wiki/decisions/`: 의사결정, 결정권자, 근거, 대안
- `AI-Sessions/wiki/errors/`: 실패한 접근, 재시도 금지 조건, 리스크
- `AI-Sessions/wiki/projects/`: 프로젝트별 목표, 상태, 이해관계자, 산출물
- `AI-Sessions/wiki/design/`: 팀 공통 디자인 원칙, IA, 화면 설계
- `AI-Sessions/wiki/dev-tasks/`: 개발 작업 단위, 의존성, 검증 메모

## Projects

아직 등록된 프로젝트가 없습니다.

## Decisions

아직 등록된 의사결정이 없습니다.

## Sources

아직 등록된 source 문서가 없습니다.

## Concepts

아직 등록된 concept 문서가 없습니다.

## Errors / Lessons

아직 등록된 error 문서가 없습니다.

## Design Guides

아직 등록된 design 문서가 없습니다.

## Development Tasks

아직 등록된 dev-task 문서가 없습니다.

## Conversations / Handoffs

아직 등록된 handoff 문서가 없습니다.

## Prompt Library

- [[prompts/first-setup]]: 첫 세팅 점검 요청
- [[prompts/save]]: 현재 작업 맥락 저장 요청
- [[prompts/query]]: 이전 업무 맥락 복원 요청
- [[prompts/ingest]]: raw 자료 컴파일 요청
- [[prompts/lint]]: vault 품질 점검 요청
