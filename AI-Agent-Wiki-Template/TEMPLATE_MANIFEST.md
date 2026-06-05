# Template Manifest

## Name

AI-Agent-Wiki-Template

## Version

1.0.0

## Purpose

더미 데이터 없는 Obsidian 기반 AI 업무 위키 템플릿입니다.

Claude Code, Codex, 기타 AI 에이전트가 동일한 업무 맥락을 공유하고, 저장과 참조를 반복 가능한 회사 업무 프로세스로 운영하도록 돕습니다.

## Operating Contract

- 사람용 가이드라인은 한국어로 작성합니다.
- 에이전트 명령 키워드는 `save`, `ingest`, `query`, `lint`로 고정합니다.
- raw는 불변 원천 자료입니다.
- wiki는 에이전트가 유지하는 컴파일된 업무 지식입니다.
- conversations는 다음 세션 인수인계가 필요한 경우에만 사용합니다.
- 중요한 저장 후에는 `index.md`와 `log.md`를 함께 갱신합니다.
- 저장 전에는 5가지 저장 필터를 반드시 적용합니다.

## Required Files

- `README.md`
- `START_HERE.md`
- `CLAUDE.md`
- `AGENTS.md`
- `index.md`
- `log.md`
- `VERSION`
- `LICENSE.md`
- `TEMPLATE_MANIFEST.md`

## Required Directories

- `AI-Sessions/raw/`
- `AI-Sessions/conversations/`
- `AI-Sessions/wiki/sources/`
- `AI-Sessions/wiki/concepts/`
- `AI-Sessions/wiki/decisions/`
- `AI-Sessions/wiki/errors/`
- `AI-Sessions/wiki/projects/`
- `AI-Sessions/wiki/design/`
- `AI-Sessions/wiki/dev-tasks/`
- `prompts/`
- `scripts/`

## Required Empty Directory Markers

- `AI-Sessions/raw/.gitkeep`
- `AI-Sessions/conversations/.gitkeep`
- `AI-Sessions/wiki/sources/.gitkeep`
- `AI-Sessions/wiki/concepts/.gitkeep`
- `AI-Sessions/wiki/decisions/.gitkeep`
- `AI-Sessions/wiki/errors/.gitkeep`
- `AI-Sessions/wiki/projects/.gitkeep`
- `AI-Sessions/wiki/design/.gitkeep`
- `AI-Sessions/wiki/dev-tasks/.gitkeep`

## Distribution Rule

배포 ZIP에는 실제 고객 정보, 실제 프로젝트 자료, API 키, 인증 정보, 개인 메모, 예시 회의록을 넣지 않습니다.

## First Prompt

첫 실행 프롬프트는 `START_HERE.md`와 `prompts/first-setup.md`에 있습니다.
