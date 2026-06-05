# AI-Agent-Wiki-Template

더미 데이터 없는 Obsidian AI 업무 위키 템플릿입니다.

이 템플릿은 Claude Code, Codex 같은 AI 에이전트가 회사 업무 맥락을 저장하고 다시 참조할 수 있도록 만든 빈 Obsidian vault입니다. 핵심 목적은 개인 메모 정리가 아니라, 여러 AI 에이전트와 동료가 같은 업무 맥락을 공유하는 안정적인 비즈니스 프로세스를 만드는 것입니다.

## 빠른 시작

1. 이 폴더를 내려받아 압축을 풉니다.
2. Obsidian에서 `Open folder as vault`를 선택합니다.
3. 이 폴더를 vault로 엽니다.
4. Claude Code 또는 Codex를 이 폴더에서 실행합니다.
5. `START_HERE.md`의 첫 실행 프롬프트를 에이전트에게 붙여넣습니다.

## 핵심 설계

이 템플릿은 Karpathy LLM Wiki 패턴을 회사 업무용으로 적용합니다.

- raw 자료는 불변 원천입니다.
- wiki 문서는 에이전트가 작성하고 유지하는 컴파일된 업무 지식입니다.
- `CLAUDE.md`와 `AGENTS.md`는 에이전트가 따르는 운영 스키마입니다.
- `index.md`는 content-oriented 지도입니다.
- `log.md`는 chronological 감사 기록입니다.

## 추천 사용 순서

1. 빈 템플릿 상태로 에이전트에게 구조 점검을 맡깁니다.
2. `AI-Sessions/raw/`에 실제 업무 자료를 조금만 넣고 `ingest`를 테스트합니다.
3. `save`, `query`, `lint`가 예상대로 동작하는지 확인합니다.
4. 그 다음 실제 프로젝트 자료를 단계적으로 추가합니다.

## 포함된 것

- 빈 raw 저장소
- 빈 wiki 저장소
- 세션 인수인계 폴더
- Claude Code용 `CLAUDE.md`
- Codex용 `AGENTS.md`
- vault 지도 `index.md`
- 작업 로그 `log.md`
- 복사해서 쓰는 첫 실행 프롬프트 `START_HERE.md`
- 상황별 프롬프트 모음 `prompts/`
- 템플릿 검증 스크립트 `scripts/validate-template.sh`

## 포함하지 않는 것

- 예시 고객 정보
- 예시 프로젝트
- 예시 회의록
- 개인 메모
- API 키나 인증 정보
- 실제 업무 자료

## 폴더 구조

```text
AI-Agent-Wiki-Template/
├── CLAUDE.md
├── AGENTS.md
├── START_HERE.md
├── README.md
├── VERSION
├── index.md
├── log.md
├── prompts/
├── scripts/
└── AI-Sessions/
    ├── raw/
    ├── conversations/
    └── wiki/
        ├── sources/
        ├── concepts/
        ├── decisions/
        ├── errors/
        ├── projects/
        ├── design/
        └── dev-tasks/
```

## 명령 키워드

사람이 읽는 가이드라인은 한국어로 작성합니다. 에이전트가 실행하는 명령 키워드는 영어로 고정합니다.

- `save`: 저장 필터를 통과한 현재 작업 맥락을 저장합니다.
- `ingest`: raw 자료를 읽고 wiki 자료로 컴파일합니다.
- `query`: wiki와 log를 참조해 이전 맥락을 복원합니다.
- `lint`: vault 구조와 규칙 위반을 점검합니다.

## 저장 필터

아래 조건 중 하나 이상을 만족할 때만 wiki 또는 conversations에 저장합니다.

1. 향후 실무에 반복해서 재사용될 데이터인가?
2. 다른 에이전트나 동료가 프로젝트를 이어받기 위해 반드시 읽어야 하는가?
3. 의사결정의 근거와 결정권자를 나중에 추적할 필요가 있는가?
4. 실패한 방식이라 다시 시도하면 안 되는 리스크 정보인가?
5. 팀 전체가 맞추어야 하는 공통 규칙이나 디자인 가이드인가?

하나도 만족하지 않는 일회성 답변은 저장하지 않습니다.

## 중요한 운영 원칙

- `AI-Sessions/raw/`는 불변 자료 저장소입니다. 에이전트가 기존 원본을 수정하지 않게 하세요.
- `AI-Sessions/wiki/`는 가공된 지식 저장소입니다. 요약, 결정, 프로젝트 맥락은 여기에 둡니다.
- `AI-Sessions/conversations/`는 세션 인수인계가 필요할 때만 사용합니다.
- 중요한 저장 후에는 `index.md`와 `log.md`를 함께 갱신합니다.
- decision 문서에는 결정권자와 근거를 남깁니다.
- error 문서에는 다시 시도하면 안 되는 조건을 남깁니다.

## 배포 전 검증

터미널에서 아래 명령을 실행합니다.

```bash
./scripts/validate-template.sh
```

검증 스크립트는 필수 파일과 폴더가 있는지, 템플릿에 더미 데이터나 민감정보로 오해될 수 있는 내용이 섞이지 않았는지 확인합니다.
