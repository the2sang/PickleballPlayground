---
phase: 02-deck-card-crud
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - app/services/flashcards/paste_import_service.rb
  - spec/services/flashcards/paste_import_service_spec.rb
  - app/javascript/controllers/card_form_controller.js
  - app/views/decks/_card_edit_form.html.erb
  - config/routes.rb
findings:
  critical: 2
  warning: 5
  info: 3
  total: 10
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Five files from the Phase 02 gap closure plan were reviewed at standard depth: the
`PasteImportService` (separator-conflict fix CR-01, batch-duplicate fix CR-02), its spec
suite, the `card_form_controller.js` Stimulus Escape handler fix, the `_card_edit_form.html.erb`
cancel-target addition, and `config/routes.rb`. Card model, deck model, and the cards
controller were also read for cross-reference.

The separator-conflict detection (CR-01) is correctly implemented using column-count
rather than field-content inspection. The batch-duplicate detection (CR-02) is correctly
implemented. Two critical issues were found unrelated to the named fixes: the paste
service never assigns `position` to imported cards (ordering corruption risk), and
`button_to` is nested inside `form_with` in the edit partial (invalid HTML5 that silently
breaks in some browsers). Five warnings and three info items are documented below.

---

## Critical Issues

### CR-01: `save_cards!` Never Sets `position` — Imported Cards Land at position=0

**File:** `app/services/flashcards/paste_import_service.rb:73`

**Issue:** `@deck.cards.create!` does not pass a `position:` value. The schema default is 0,
so every paste-imported card is created with `position = 0`. The `Deck` model sorts cards
via `has_many :cards, -> { order(:position) }` and `scope :ordered, -> { order(:position, :id) }`.
All N imported cards share position=0 and will cluster at the front of any ordered list,
sorted only by `id` among themselves. Any existing card that was assigned position > 0 (e.g.,
through a future reordering feature) will be pushed behind the imported cluster without the
user's knowledge.

Cross-check: `CardsController#create` (the single-card UI path) also omits `position:`, so
both paths share the same default-0 behaviour today. However, the paste path creates many
cards at once, making the collision surface larger. If positions are ever assigned by any
future migration, seed, or drag-and-drop feature, this silent assumption will corrupt ordering
in bulk.

**Fix:**
```ruby
def save_cards!(cards)
  saved = 0
  ActiveRecord::Base.transaction do
    next_position = (@deck.cards.maximum(:position) || -1) + 1
    cards.each_with_index do |c, i|
      @deck.cards.create!(
        front: c.front, back: c.back, hint: c.hint,
        tags: c.tags, card_type: :basic,
        position: next_position + i
      )
      saved += 1
    end
  end
  Result.new(
    success?: true, preview_cards: cards, importable_count: cards.size,
    warnings: [], errors: [], saved_count: saved
  )
rescue ActiveRecord::RecordInvalid => e
  failure("저장 실패 (전체 롤백): #{e.message}")
end
```

---

### CR-02: `button_to` (Delete) Nested Inside `form_with` — Invalid HTML5, Delete May Silently Fail

**File:** `app/views/decks/_card_edit_form.html.erb:19`

**Issue:** `button_to` renders its own `<form>` element. Rails places it at line 19, which is
inside the outer `<form>` block opened by `form_with` on line 4. HTML5 forbids nested `<form>`
elements. Browsers auto-close the outer form when they parse the inner `<form>` opening tag.
Depending on where in the DOM the correction occurs, the delete button's inner form may be
treated as a sibling of the outer form, not a child, causing the click to submit to a
different target or fail entirely. The current field order (submit + cancel link appear before
`button_to` on lines 15-18) means the edit-form fields are likely intact, but the correction
is browser-specific and fragile.

**Fix:** Move the `button_to` call outside the `form_with` block:
```erb
<td colspan="5" data-controller="card-form"
                data-action="keydown->card-form#handleKeydown">
  <%= form_with model: [deck, card], class: "card-edit-form" do |f| %>
    <%# ... error block, fields, submit, cancel link ... %>
    <%= f.submit "저장", class: "btn btn--primary btn--sm" %>
    <%= link_to "취소", deck_path(deck),
        data: { turbo_frame: "_top", card_form_target: "cancel" },
        class: "btn btn--ghost btn--sm" %>
  <% end %>
  <%= button_to "삭제", deck_card_path(deck, card), method: :delete,
      class: "btn btn--danger btn--sm",
      form: { data: { turbo_confirm: "정말 삭제하시겠습니까?" } } %>
</td>
```

---

## Warnings

### WR-01: Mixed-Validity Save Silently Skips Warned Rows With No User Feedback

**File:** `app/services/flashcards/paste_import_service.rb:44-53`

**Issue:** When `importable > 0` but the batch also contains warned rows (e.g., 3 clean cards
plus 1 duplicate), `save_cards!` is called with only the 3 importable cards. The returned
`Result` sets `warnings: []` and `preview_cards:` to only the saved subset. The caller
(`Cards::ImportsController#create`) redirects on success with `"#{@result.saved_count}장을
가져왔습니다."` — no indication that any rows were silently dropped. The CR-02 spec only
covers the all-duplicate case (importable == 0); the partial-success mixed case is not
exercised and the user gets no signal.

**Fix:** Propagate skipped-row information in the success result:
```ruby
def save_cards!(importable_cards)
  # pass original parsed list to report skipped rows
  skipped_warnings = ...  # built before filtering
  saved = 0
  # ... transaction ...
  Result.new(
    success?: true, preview_cards: importable_cards,
    importable_count: importable_cards.size,
    warnings: skipped_warnings,
    errors: [], saved_count: saved
  )
end
```
Or surface the skip count in the controller redirect notice:
`"#{result.saved_count}장 저장됨 (#{skipped}장 건너뜀)."`.

---

### WR-02: Stimulus Escape Handler Frame-ID Check Matches Non-Card Frames

**File:** `app/javascript/controllers/card_form_controller.js:19`

**Issue:** `frame.id.startsWith("card_")` will also match any turbo-frame whose ID starts
with `card_` — e.g., `card_form`, `card_new`, `card_imports`, or any future frame sharing
the prefix. The comment "add form은 frame 밖에 위치 — Escape 무시" is accurate for the
current template structure but is a structural assumption that cannot be enforced by this
check. If a future partial wraps an add-form in a frame named `card_add_form`, Escape will
unexpectedly trigger `cancelTarget.click()`.

**Fix:** Constrain to numeric IDs:
```javascript
if (event.key === "Escape") {
  const frame = this.element.closest("turbo-frame")
  if (frame && /^card_\d+$/.test(frame.id)) {
    event.preventDefault()
    if (this.hasCancelTarget) this.cancelTarget.click()
  }
}
```

---

### WR-03: Rollback Spec Does Not Test the Transactional Rollback Path

**File:** `spec/services/flashcards/paste_import_service_spec.rb:102`

**Issue:** The test "한 카드 저장 실패 시 전체 롤백" (line 102) submits a line with no
`back`, which produces `importable? == false` for all rows, triggering the `importable == 0`
guard before the transaction begins. The comment in the spec acknowledges this. The actual
`rescue ActiveRecord::RecordInvalid` path in `save_cards!` — where some cards pass
`importable?`, enter the transaction, and then `create!` raises on a later row — is never
exercised. The advertised "전체 롤백" guarantee has no regression test.

**Fix:**
```ruby
it "create! 실패 시 이미 삽입된 행도 전체 롤백된다" do
  call_count = 0
  allow_any_instance_of(ActiveRecord::Associations::CollectionProxy)
    .to receive(:create!).and_wrap_original do |original, *args|
      call_count += 1
      raise ActiveRecord::RecordInvalid.new(Card.new) if call_count == 2
      original.call(*args)
    end
  text = "앞1\t뒤1\n앞2\t뒤2\n앞3\t뒤3"
  expect {
    result = described_class.call(text: text, separator: "\t", deck: deck, mode: :save)
    expect(result.success?).to be false
  }.not_to change { deck.cards.count }
end
```

---

### WR-04: Cancel Link Forces Full-Page Reload via `turbo_frame: "_top"`

**File:** `app/views/decks/_card_edit_form.html.erb:16`

**Issue:** The cancel link uses `data: { turbo_frame: "_top" }`, which breaks out of all
turbo frames and performs a full-page navigation to `deck_path(deck)`. This discards scroll
position and any other in-flight inline edits. The partial is rendered inside a
`turbo_frame_tag "card_#{card.id}"`, so a frame-scoped reload of that frame would restore
the read-only row without a full-page visit.

**Fix:** Target the card's own frame instead:
```erb
<%= link_to "취소", deck_card_path(deck, card),
    data: { turbo_frame: "card_#{card.id}", card_form_target: "cancel" },
    class: "btn btn--ghost btn--sm" %>
```
Requires the `cards#show` action (or a read-only partial rendered by `cards#edit` on cancel)
to be available.

---

### WR-05: `PasteImportService` Does Not Inherit from `ApplicationService`

**File:** `app/services/flashcards/paste_import_service.rb:2`

**Issue:** Project rules in `.claude/rules/services.md` specify: "Inherit from `ApplicationService`
base class (`app/services/application_service.rb`)." The service uses plain `class PasteImportService`
with no base class. Additionally, the rules specify `Data.define` for result objects; the
service uses `Struct.new`. Note: `ApplicationService` does not currently exist in the repo
(confirmed via filesystem search), so the convention is aspirational, but the service should
adopt it when the base class is introduced to avoid technical debt accumulation.

**Fix:** When `application_service.rb` is created, update the service to inherit from it.
Replace `Struct.new(..., keyword_init: true)` with `Data.define(...)` for `ParsedCard` and
`Result` to align with project conventions.

---

## Info

### IN-01: `batch_dupes` Computes `parsed.map(&:front).compact_blank` Twice

**File:** `app/services/flashcards/paste_import_service.rb:33-35`

**Issue:** Line 33 assigns `fronts = parsed.map(&:front).compact_blank`. Line 35 recomputes
`parsed.map(&:front).compact_blank.tally...` from scratch. The second pass is redundant.

**Fix:**
```ruby
fronts = parsed.map(&:front).compact_blank
existing_fronts = @deck.cards.where(front: fronts).pluck(:front).to_set
batch_dupes = fronts.tally.select { |_, count| count > 1 }.keys.to_set
```

---

### IN-02: `card_type: :basic` in `save_cards!` Is Redundant

**File:** `app/services/flashcards/paste_import_service.rb:75`

**Issue:** The `Card` enum declares `{ basic: 0 }, default: :basic`. Passing `card_type: :basic`
explicitly in `create!` duplicates the default with no added clarity.

**Fix:** Remove the `card_type: :basic` argument, or add an inline comment if the explicit
assignment is intentional documentation: `card_type: :basic # v1 only`.

---

### IN-03: Spec Has No CRLF Test and No Multi-Warning Row Test

**File:** `spec/services/flashcards/paste_import_service_spec.rb`

**Issue:** No test exercises Windows-style CRLF line endings (`\r\n`). The service uses
`@text.lines.map(&:chomp)` which correctly handles both `\n` and `\r\n` via `chomp`, but
this is unverified. Additionally, no test places a row that accumulates multiple simultaneous
warnings (e.g., blank front AND separator collision), which would exercise the `warnings <<`
accumulation path more thoroughly.

**Fix:**
```ruby
it "CRLF 줄바꿈을 올바르게 처리한다" do
  text = "앞면\t뒷면\r\n다음\t카드\r\n"
  result = described_class.call(text: text, separator: "\t", deck: deck, mode: :preview)
  expect(result.preview_cards.size).to eq 2
  expect(result.preview_cards.all?(&:importable?)).to be true
end

it "한 행에 복수 경고가 누적된다" do
  text = "\t\t\t\t\t"  # blank front + blank back + excess columns
  result = described_class.call(text: text, separator: "\t", deck: deck, mode: :preview)
  expect(result.preview_cards.first.warnings.size).to be >= 2
end
```

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
