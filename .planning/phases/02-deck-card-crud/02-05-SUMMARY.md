---
plan: 02-05
phase: 02-deck-card-crud
status: complete
wave: 4
gap_closure: true
completed: 2025-05-30
key-files:
  created:
    - spec/services/flashcards/paste_import_service_spec.rb (CR-01/CR-02 contexts added)
  modified:
    - app/services/flashcards/paste_import_service.rb
    - app/javascript/controllers/card_form_controller.js
    - app/views/decks/_card_edit_form.html.erb
    - config/routes.rb
---

## Objective

Phase 02 검증에서 발견된 gap(CR-01, CR-02, WR-01, WR-03)을 TDD로 수정.

## Self-Check: PASSED

## What Was Built

### CR-01 — parse_line 구분자 충돌 감지 수정

**변경 전 (데드코드):**
```ruby
if [ front, back, hint, tags ].compact.any? { |f| f.include?(@separator) }
  warnings << "구분자 충돌 — 내용에 '#{@separator}' 포함"
end
```
split 후 각 element에 separator가 없으므로 조건이 항상 false.

**변경 후:**
```ruby
if parts.compact_blank.size > 4
  warnings << "구분자 충돌 — 열 수 초과 (#{parts.compact_blank.size}개 열 감지됨)"
end
```
빈 후행 요소를 compact_blank로 제거한 후 크기 비교 → 실제 초과 열 감지.

Grep 검증:
- `grep -c 'compact_blank.size > 4' ...` → 1
- `grep -c 'f.include?(@separator)' ...` → 0

### CR-02 — call 메서드 배치 내 중복 감지 추가

existing_fronts pluck 쿼리 이후, 기존 중복 검사 루프와 통합:

```ruby
batch_dupes = parsed.map(&:front).compact_blank.tally.select { |_, count| count > 1 }.keys.to_set
parsed.each do |c|
  next if c.front.blank?
  c.warnings << "덱 내 중복 카드: #{c.front}" if existing_fronts.include?(c.front)
  c.warnings << "배치 내 중복 카드: #{c.front}" if batch_dupes.include?(c.front)
end
```

Grep 검증:
- `grep -c 'batch_dupes' ...` → 2
- `grep -c 'tally' ...` → 1

### CR-01/CR-02 Spec 추가 (TDD)

RED 커밋 → 3개 실패 확인 → GREEN 커밋 → 12개 전체 통과.

추가된 context:
- `구분자 충돌 감지 (CR-01)` — 3 examples
  - 5열 입력 → 경고 + importable? false
  - 후행 빈 열 → 경고 없음
  - 4열 이하 → 경고 없음
- `배치 내 중복 감지 (CR-02)` — 2 examples
  - 동일 front 2행 → 두 행 모두 경고
  - 배치 중복 → save 거부 (deck.cards.count 불변)

### WR-01 — Escape 핸들러 수정 (Stimulus cancelTarget)

`app/javascript/controllers/card_form_controller.js`:

static targets에 "cancel" 추가:
```js
static targets = ["front", "counter", "cancel"]
```

Escape 핸들러 교체:
```js
// Before (no-op — removeAttribute 후 reload가 아무 동작 안 함)
frame.removeAttribute("src")
if (typeof frame.reload === "function") { frame.reload() }

// After
if (this.hasCancelTarget) this.cancelTarget.click()
```

`app/views/decks/_card_edit_form.html.erb`:
```erb
<%= link_to "취소", deck_path(deck),
    data: { turbo_frame: "_top", card_form_target: "cancel" },
    class: "btn btn--ghost btn--sm" %>
```

Grep 검증:
- `grep -c 'removeAttribute' card_form_controller.js` → 0
- `grep -c 'cancelTarget' card_form_controller.js` → 1
- `grep -c 'hasCancelTarget' card_form_controller.js` → 1
- `grep -c 'card_form_target: "cancel"' _card_edit_form.html.erb` → 1

### WR-03 — :new 라우트 제거

`config/routes.rb`:
```ruby
# Before
resources :cards, only: %i[new create edit update destroy]

# After
resources :cards, only: %i[create edit update destroy]
```

`bin/rails routes | grep 'cards#new'` → 없음 ✓

### WR-02 — DEFERRED

Decision #5(잠긴 결정) 준수 — 제품 판단 필요.

## Test Results

```
RSpec: 461 examples, 0 failures
```

전체 회귀 없음.

## Deviations

없음. WR-02는 계획대로 deferred.
