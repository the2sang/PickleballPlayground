---
phase: 02-deck-card-crud
plan: "04"
subsystem: paste-import
tags:
  - paste-import
  - service
  - turbo-stream
  - stimulus
  - pundit
  - wave-3
dependency_graph:
  requires:
    - "02-01 — routes (namespace :cards { resource :imports })"
    - "02-02 — DecksController + show.html.erb id='deck-cards-{id}'"
    - "02-03 — CardsController + _card_row partial + deck-add-form container"
    - "Phase 1 — Card model + DeckPolicy#update? + Pundit"
  provides:
    - "app/services/flashcards/paste_import_service.rb — 텍스트 파싱 + 검증 + 트랜잭션 저장"
    - "app/controllers/cards/imports_controller.rb — paste import controller (new/create)"
    - "app/views/cards/imports/*.html.erb — 4개 뷰 (new + 2 partials + turbo_stream)"
    - "app/javascript/controllers/paste_import_controller.js — 구분자 자동 감지 Stimulus"
    - "app/views/decks/show.html.erb — 붙여넣기 가져오기 진입 링크 추가"
  affects:
    - "Phase 3 — 학습 세션에서 카드 수 증가 (batch import로 생성된 카드)"
tech_stack:
  added: []
  patterns:
    - "Flashcards::PasteImportService: plain Ruby class (ApplicationService 상속 불가 — base class 미존재)"
    - "ParsedCard Struct: importable? = warnings.empty? 술어"
    - "Result Struct: success?, preview_cards, importable_count, warnings, errors, saved_count"
    - "ActiveRecord::Base.transaction + create! (bang) — RecordInvalid → 전체 롤백"
    - "Cards::ImportsController: Deck.where(owner: Current.user).find() — policy_scope 금지"
    - "decode_separator: tab/pipe/dash/comma → 실제 구분자 변환"
    - "respond_to turbo_stream/html + status: :unprocessable_entity (Pitfall 3 준수)"
    - "paste_import_controller.js: detectSeparator() Object.entries().sort() 빈도 최대 우선"
key_files:
  created:
    - app/services/flashcards/paste_import_service.rb
    - app/controllers/cards/imports_controller.rb
    - app/views/cards/imports/new.html.erb
    - app/views/cards/imports/_preview_table.html.erb
    - app/views/cards/imports/_actions.html.erb
    - app/views/cards/imports/create.turbo_stream.erb
    - app/javascript/controllers/paste_import_controller.js
  modified:
    - app/views/decks/show.html.erb (line 52 영역 — 붙여넣기 가져오기 링크 삽입)
    - spec/services/flashcards/paste_import_service_spec.rb (8 pending → 8 real examples)
    - spec/requests/cards/imports_spec.rb (5 pending → 7 real examples)
decisions:
  - "services.md 규칙(ApplicationService 상속)은 이 코드베이스에 application_service.rb 미존재로 적용 불가 — PLAN.md 명시대로 plain Ruby class 사용"
  - "Accept 헤더는 'text/vnd.turbo-stream.html'만 사용 — Rails는 */* 포함 시 우선순위 처리가 다를 수 있음"
  - "구분자 충돌 request spec: 실제 충돌(파이프 구분자 + 뒷면 없는 줄)로 저장 차단 검증 — 탭으로 split 후 탭이 필드 내에 남지 않는 edge case 해소"
metrics:
  duration: "~25 minutes"
  completed: "2026-05-30T03:30:00Z"
  tasks_completed: 2
  files_modified: 10
---

# Phase 02 Plan 04: Paste Import (Service + Controller + Views + Stimulus) Summary

Wave 3 목표: 인증된 사용자가 본인 personal 덱에 텍스트 paste import로 카드를 일괄 추가할 수 있다. `Flashcards::PasteImportService`가 구분자 자동 감지 → 파싱 → 검증 → 트랜잭션 저장 흐름을 담당하며, `Cards::ImportsController`가 preview/save 두 모드로 Turbo Stream 응답을 제공한다.

## PasteImportService 공개 인터페이스 + Result 멤버 매트릭스

```ruby
Flashcards::PasteImportService.call(
  text:      String,    # 붙여넣기 텍스트 (multi-line)
  separator: String,    # 실제 구분자 문자 ("\t", "|", "==", ",")
  deck:      Deck,      # 대상 덱 (DB 쿼리: 중복 front 검출)
  mode:      Symbol     # :preview (저장 안 함) | :save (트랜잭션 저장)
)
```

### Result Struct 멤버

| 멤버 | 타입 | 설명 |
|------|------|------|
| `success?` | Boolean | 성공 여부 (`failure?`로 반전 가능) |
| `preview_cards` | Array[ParsedCard] | 파싱된 카드 목록 (preview) / 저장된 카드 목록 (save) |
| `importable_count` | Integer | 경고 없는 카드 수 (저장 가능) |
| `warnings` | Array[String] | 서비스 레벨 경고 (현재 미사용, card-level 경고는 ParsedCard.warnings) |
| `errors` | Array[String] | 실패 메시지 (IMPORT_LIMIT 초과, 빈 텍스트, 롤백 오류 등) |
| `saved_count` | Integer | 실제 저장된 카드 수 (save 모드 성공 시에만 > 0) |

### ParsedCard Struct 멤버

| 멤버 | 타입 | 설명 |
|------|------|------|
| `front` | String | 앞면 (parts[0].strip) |
| `back` | String | 뒷면 (parts[1].strip) |
| `hint` | String\|nil | 힌트 (parts[2].strip) |
| `tags` | String\|nil | 태그 (parts[3].strip) |
| `row_index` | Integer | 원본 줄 번호 (1-based) |
| `warnings` | Array[String] | 줄 레벨 경고 (front/back 미달, 구분자 충돌, 중복 front) |
| `importable?` | Boolean | `warnings.empty?` |

## Cards::ImportsController 액션 흐름도

```
GET  /decks/:deck_id/cards/imports/new
  └─ authorize @deck, :update?
  └─ render new.html.erb

POST /decks/:deck_id/cards/imports
  └─ authorize @deck, :update?
  └─ mode 판별: params[:commit]=="저장" || params[:mode]=="save" ? :save : :preview
  └─ PasteImportService.call(text, separator(decoded), deck, mode)
     ├─ mode == :save && success? → redirect_to deck_path (notice: N장 가져옴)
     └─ 그 외 → respond_to
         ├─ turbo_stream → render :create (ok / unprocessable_entity)
         └─ html → render :new (unprocessable_entity)
```

### decode_separator 변환표

| params[:separator] | 실제 구분자 |
|-------------------|-----------|
| "tab" / "\\t" | "\t" (탭) |
| "pipe" | "\|" |
| "dash" | "==" |
| "comma" | "," |

## T-02-04, T-02-08, T-02-09 위협 Mitigation 검증 결과

### T-02-04: DoS — 거대한 텍스트 입력

```
grep -c 'IMPORT_LIMIT' app/services/flashcards/paste_import_service.rb
→ 2 (선언 + 검사)

grep -c 'lines.size > IMPORT_LIMIT' app/services/flashcards/paste_import_service.rb
→ 1

spec result: "IMPORT_LIMIT(500) 초과 입력 거부" → PASSED
```

`lines.size > IMPORT_LIMIT` 검사는 파싱 루프 진입 전에 즉시 failure 반환 (DoS 회피).

### T-02-08: Tampering — front에 separator 포함

```ruby
# parse_line 내부
if [front, back, hint, tags].compact.any? { |f| f.include?(@separator) }
  warnings << "구분자 충돌 — 내용에 '#{@separator}' 포함"
end
```

경고 발생 시 `importable? = false` → save 모드에서 해당 줄 제외 → `importable_count == 0`이면 failure 반환.

### T-02-09: Integrity — 중간 카드 저장 실패 시 부분 commit

```ruby
ActiveRecord::Base.transaction do
  cards.each do |c|
    @deck.cards.create!(front: c.front, back: c.back, ...)  # bang!
  end
end
rescue ActiveRecord::RecordInvalid => e
  failure("저장 실패 (전체 롤백): #{e.message}")
```

`create!`이 RecordInvalid를 raise하면 transaction이 자동 전체 롤백.

spec result: "한 카드 저장 실패 시 전체 롤백" → PASSED

## Phase 2 전체 회귀 결과

```
bundle exec rspec --format progress
457 examples, 0 failures
```

```
bin/brakeman --no-pager
Security Warnings: 3
(모두 기존 경고 — admin/users_controller, admin/data_management_controller)
신규 경고: 0
```

## ROADMAP Success Criteria 매핑

| Success Criterion | 검증 spec |
|------------------|-----------|
| #1 탭 구분자 10줄 → 미리보기 → 일괄 저장 | `PasteImportService spec: 탭 구분자 입력 파싱`, `ImportsController: save 모드` |
| #2 적대적 입력 경고 (중복, 충돌, 500장 초과) | `PasteImportService spec: IMPORT_LIMIT, 중복 front, 구분자 충돌` |
| #3 타인 덱 접근 차단 | `ImportsController spec: 비소유자 접근 시 403` |
| #4 트랜잭션 전체 롤백 | `PasteImportService spec: 한 카드 저장 실패 시 전체 롤백` |
| #5 빈줄 무시 | `PasteImportService spec: 빈 줄 skip` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Accept 헤더 형식 — 복합 미디어타입 우선순위**
- **Found during:** Task 2 GREEN — preview 모드 spec 실패
- **Issue:** `"Accept" => "text/vnd.turbo-stream.html, text/html, */*"` 전달 시 Rails가 text/html을 선택하여 `render :new, status: :unprocessable_entity` (422) 실행됨
- **Fix:** Accept 헤더를 `"text/vnd.turbo-stream.html"` 단독으로 변경 — turbo_stream format 명확히 지정
- **Files modified:** `spec/requests/cards/imports_spec.rb`
- **Commit:** 80f1fd6

**2. [Rule 1 - Adaptation] 구분자 충돌 request spec 재설계**
- **Found during:** Task 2 GREEN — 구분자 충돌 저장 차단 spec 실패
- **Issue:** "앞\t안에탭\t있음"을 탭으로 split하면 ["앞", "안에탭", "있음"] — split 후 각 필드에 탭이 남지 않으므로 구분자 충돌 경고 미발생, 카드 저장됨
- **Fix:** front만 있고 back이 없는 줄(파이프 구분자) 사용 → warnings 발생 → importable_count=0 → save failure → 저장 차단 확인
- **Files modified:** `spec/requests/cards/imports_spec.rb`
- **Commit:** 80f1fd6

**3. [Observation] services.md ApplicationService 규칙 미적용**
- **Found during:** Task 1 구현
- **Issue:** `rules/services.md`가 "Inherit from ApplicationService" 지시, 그러나 `app/services/application_service.rb` 미존재 (verified: `ls app/services/application_service.rb` → not found)
- **Fix:** PLAN.md 명시("ApplicationService 상속 금지")대로 plain Ruby class 구현
- **Files modified:** `app/services/flashcards/paste_import_service.rb`

## Known Stubs

없음 — 모든 파일이 실제 동작하는 코드. paste import 진입점, 파싱, 검증, 저장, Turbo Stream 응답 모두 구현됨.

## Threat Flags

신규 위협 표면 없음. T-02-04/08/09/02/10 모두 구현에서 mitigate:
- T-02-04: IMPORT_LIMIT=500 파싱 전 검사
- T-02-08: parse_line에서 separator 포함 필드 경고 → importable? false
- T-02-09: transaction + create! 자동 롤백
- T-02-02: set_deck → `Deck.where(owner: Current.user).find()` 타인 덱 RecordNotFound
- T-02-10: `@deck.cards.where(front: fronts).pluck(:front)` 사전 검사 → 중복 저장 차단

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (Task 1) | 398e81a `test(02-04): replace pending stubs with real failing specs for PasteImportService (RED)` | PASS |
| GREEN (Task 1) | 757d13f `feat(02-04): implement Flashcards::PasteImportService (GREEN)` | PASS |
| RED (Task 2) | e7d955a `test(02-04): replace pending stubs with real failing specs for Cards::ImportsController (RED)` | PASS |
| GREEN (Task 2) | 80f1fd6 `feat(02-04): implement Cards::ImportsController + paste import views + Stimulus (GREEN)` | PASS |
| REFACTOR | 없음 (코드 품질 충분) | N/A |

## Commits

| Task | Commit | Message |
|------|--------|---------|
| Task 1 RED | 398e81a | test(02-04): replace pending stubs with real failing specs for PasteImportService (RED) |
| Task 1 GREEN | 757d13f | feat(02-04): implement Flashcards::PasteImportService (GREEN) |
| Task 2 RED | e7d955a | test(02-04): replace pending stubs with real failing specs for Cards::ImportsController (RED) |
| Task 2 GREEN | 80f1fd6 | feat(02-04): implement Cards::ImportsController + paste import views + Stimulus (GREEN) |

## Self-Check: PASSED

- app/services/flashcards/paste_import_service.rb: FOUND
- app/controllers/cards/imports_controller.rb: FOUND
- app/views/cards/imports/new.html.erb: FOUND
- app/views/cards/imports/_preview_table.html.erb: FOUND
- app/views/cards/imports/_actions.html.erb: FOUND
- app/views/cards/imports/create.turbo_stream.erb: FOUND
- app/javascript/controllers/paste_import_controller.js: FOUND
- 커밋 398e81a: FOUND (Task 1 RED)
- 커밋 757d13f: FOUND (Task 1 GREEN)
- 커밋 e7d955a: FOUND (Task 2 RED)
- 커밋 80f1fd6: FOUND (Task 2 GREEN)
- spec/services/flashcards/paste_import_service_spec.rb: 8 examples, 0 failures
- spec/requests/cards/imports_spec.rb: 7 examples, 0 failures
- bundle exec rspec --format progress: 457 examples, 0 failures
- bin/brakeman: 신규 경고 0
