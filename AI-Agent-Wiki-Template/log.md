# Agent Work Log

이 파일은 vault의 chronological 작업 기록입니다.

중요한 `save`, `ingest`, `query`, `lint` 작업이 끝날 때 append-only로 항목을 추가합니다. 업무 감사와 인수인계를 위한 기록이므로 기존 항목을 조용히 고치거나 삭제하지 않습니다.

## Format

각 항목은 아래 형식을 따릅니다.

```text
## [YYYY-MM-DD HH:mm] command | summary

- Files: [[path-or-page]], [[path-or-page]]
- Reason: 저장 필터를 통과한 이유
- Notes: 결정, 리스크, 다음 액션
```

`command`는 반드시 `save`, `ingest`, `query`, `lint` 중 하나를 사용합니다.

## Log
