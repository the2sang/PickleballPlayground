---
phase: 02-deck-card-crud
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 32
files_reviewed_list:
  - app/controllers/cards/imports_controller.rb
  - app/controllers/cards_controller.rb
  - app/controllers/decks_controller.rb
  - app/javascript/controllers/card_form_controller.js
  - app/javascript/controllers/paste_import_controller.js
  - app/policies/deck_policy.rb
  - app/services/flashcards/paste_import_service.rb
  - app/views/cards/create.turbo_stream.erb
  - app/views/cards/destroy.turbo_stream.erb
  - app/views/cards/edit.html.erb
  - app/views/cards/imports/_actions.html.erb
  - app/views/cards/imports/_preview_table.html.erb
  - app/views/cards/imports/create.turbo_stream.erb
  - app/views/cards/imports/new.html.erb
  - app/views/cards/update.turbo_stream.erb
  - app/views/decks/_card_add_form.html.erb
  - app/views/decks/_card_edit_form.html.erb
  - app/views/decks/_card_row.html.erb
  - app/views/decks/_deck.html.erb
  - app/views/decks/_form.html.erb
  - app/views/decks/edit.html.erb
  - app/views/decks/index.html.erb
  - app/views/decks/new.html.erb
  - app/views/decks/show.html.erb
  - app/views/layouts/application.html.erb
  - config/routes.rb
  - spec/requests/cards/imports_spec.rb
  - spec/requests/cards_spec.rb
  - spec/requests/decks_spec.rb
  - spec/services/flashcards/paste_import_service_spec.rb
  - spec/support/system_test_helpers.rb
  - spec/system/deck_authoring_spec.rb
findings:
  critical: 2
  warning: 6
  info: 1
  total: 9
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 32
**Status:** issues_found

## Summary

Reviewed the full deck + card CRUD implementation including controllers, Pundit policies, the paste-import service, Turbo Stream views, Stimulus controllers, routes, and all specs. The authorization model is correctly structured — owner-scoped `set_deck` in `CardsController` and `Cards::ImportsController`, policy delegation in `CardPolicy`, and `DeckPolicy` default-deny stubs are all sound. Turbo Stream error responses correctly use `status: :unprocessable_entity`. No SQL injection, mass-assignment, or authentication bypass issues were found.

Two correctness defects require fixing before ship: the separator-collision guard in `PasteImportService` is logically dead and can never fire (split strips the separator before the check runs), and the in-batch duplicate detection silently allows two rows with the same `front` to be saved when both are pasted together. Six additional quality and behavioral warnings are called out below.

---

## Critical Issues

### CR-01: Separator Collision Detection Is Dead Code — Warning Never Fires

**File:** `app/services/flashcards/paste_import_service.rb:60`

**Issue:** The check for separator collision inside `parse_line` can never trigger. `split(@separator, -1)` is called on line 56 first — by definition that operation removes all occurrences of the separator from the resulting fields. By the time line 60 runs `f.include?(@separator)`, none of the fields can contain the separator. The intended guard (warn when a field value contains the separator, signaling that the user pasted content with embedded delimiters) is completely non-functional. Any paste where separator characters appear inside field values silently discards the overflow columns with no user feedback.

**Concrete example:** Input `"앞면|뒤:내용에|포함됨"` with `|` separator → `split("|", -1)` → `["앞면", "뒤:내용에", "포함됨"]` → `front="앞면"`, `back="뒤:내용에"`, `hint="포함됨"`, no warning. The user's third field is silently truncated.

**Fix:** Replace the field-content check with a column-count check:

```ruby
# app/services/flashcards/paste_import_service.rb

def parse_line(line, index)
  parts = line.split(@separator, -1).map { |p| p&.strip }
  front, back, hint, tags = parts[0], parts[1], parts[2], parts[3]
  warnings = []
  warnings << "앞면 또는 뒷면이 비어 있습니다." if front.blank? || back.blank?
  # Warn when more columns than expected — indicates separator appears inside field values
  if parts.size > 4
    warnings << "구분자 충돌 — 예상보다 많은 열: #{parts.size}개 (최대 4개)"
  end
  ParsedCard.new(front: front, back: back, hint: hint, tags: tags, row_index: index, warnings: warnings)
end
```

---

### CR-02: In-Batch Duplicate `front` Values Are Not Detected

**File:** `app/services/flashcards/paste_import_service.rb:33-37`

**Issue:** The duplicate-front detection (lines 33-37) only checks against cards already in the database. If the pasted text contains two rows with the same `front` value (neither yet in the DB), both pass the duplicate guard and are saved, silently creating two cards with identical `front` values in the same deck. There is no DB-level unique index on `(deck_id, front)` (confirmed: `db/schema.rb` shows only `index_cards_on_deck_id_and_position` and `index_cards_on_deck_id`) and no model-level uniqueness validation. The documented intent ("덱 내 중복 카드" detection) is only half-implemented.

**Concrete example:** Paste `"apple\tA\napple\tB"` with tab separator in save mode → both rows have `warnings = []` → both `importable?` → both `create!` → deck has two cards with `front="apple"`.

**Fix:** After building `parsed`, cross-check fronts within the batch itself before the DB query:

```ruby
# app/services/flashcards/paste_import_service.rb, inside call

# Detect duplicates within the pasted batch itself
batch_fronts = parsed.map(&:front).compact_blank
batch_dupes  = batch_fronts.group_by(&:itself).select { |_, v| v.size > 1 }.keys.to_set
parsed.each do |c|
  c.warnings << "배치 내 중복 카드: #{c.front}" if c.front.present? && batch_dupes.include?(c.front)
end

# Then existing DB duplicate check ...
fronts = parsed.map(&:front).compact_blank
existing_fronts = @deck.cards.where(front: fronts).pluck(:front).to_set
parsed.each do |c|
  c.warnings << "덱 내 중복 카드: #{c.front}" if c.front.present? && existing_fronts.include?(c.front)
end
```

---

## Warnings

### WR-01: Escape Key Handler Cannot Restore the Read-Only Card Row

**File:** `app/javascript/controllers/card_form_controller.js:22-28`

**Issue:** When the user presses Escape inside an inline edit form, the handler calls `frame.removeAttribute("src")` followed by `frame.reload()`. Turbo's `reload()` implementation re-fetches `this.src`. After `removeAttribute("src")`, `this.src` is `""` or `null`, so `reload()` is a no-op — the edit form stays visible and the read-only card row is never restored. The Cancel button (which uses `data: { turbo_frame: "_top" }` to navigate the full page back to `deck_path`) still works, but Escape is broken.

**Fix direction:** Instead of manipulating `src`, navigate the frame to the card's read-only source URL. Store the card ID in a Stimulus value and construct the `deck_card_path`, or replace the frame's content with a `turbo_stream:replace` initiated by a lightweight server round-trip. The simplest client-side approach is:

```js
if (event.key === "Escape") {
  const frame = this.element.closest("turbo-frame")
  if (frame && frame.id.startsWith("card_")) {
    event.preventDefault()
    // Navigate the frame back to the deck show page (shows the read-only row)
    const cancelLink = this.element.querySelector("a[data-turbo-frame='_top']")
    if (cancelLink) cancelLink.click()
  }
}
```

---

### WR-02: `붙여넣기 가져오기` CTA on Index Page Links to Wrong Route

**File:** `app/views/decks/index.html.erb:20`

**Issue:** In the empty-state hero (zero personal decks), the `붙여넣기 가져오기` button links to `new_deck_path` (the new deck form), not to an import page. The import page at `new_deck_cards_imports_path` requires an existing deck, so this two-step flow is arguable, but the button label creates a false expectation — users clicking `붙여넣기 가져오기` will land on a blank "새 덱 만들기" form with no indication that import is coming next.

**Fix:** Either retitle the button to clarify the prerequisite step (`"덱 만들고 가져오기"`) or add a hint below it explaining the flow. If the UX intent is truly to import first, consider a flow where a deck is auto-created and the user is redirected to the import page.

---

### WR-03: `cards :new` Route Declared but Action Is Missing

**File:** `config/routes.rb:38`, `app/controllers/cards_controller.rb`

**Issue:** `resources :cards, only: %i[new create edit update destroy]` declares a `GET /decks/:deck_id/cards/new` route (`new_deck_card_path`), but `CardsController` has no `def new` action. Any request to that URL raises `AbstractController::ActionNotFound` in production (Rails raises a 404 to the user). Since no current view links to `new_deck_card_path`, this is a latent bug — it will be hit if a developer adds such a link without noticing the missing action.

**Fix:** Either remove `:new` from the routes or add the action:

```ruby
# config/routes.rb
resources :cards, only: %i[create edit update destroy]

# OR add to CardsController:
def new
  authorize @deck, :update?
  @card = @deck.cards.build
end
```

---

### WR-04: `sign_in` Helper Duplicated in `imports_spec.rb`

**File:** `spec/requests/cards/imports_spec.rb:8-10`

**Issue:** `imports_spec.rb` defines a local `def sign_in(u)` at line 8. An identical helper is already provided by `spec/support/request_helpers.rb` and included into all `type: :request` specs via `RSpec.configure`. The local definition shadows the shared one. If `RequestHelpers#sign_in` is ever updated (e.g., to handle 2FA or OTP), the local copy will silently diverge.

**Fix:** Delete lines 8-10 from `imports_spec.rb`. The shared helper is already available.

---

### WR-05: Separator Collision Spec Does Not Assert the Warning

**File:** `spec/services/flashcards/paste_import_service_spec.rb:35-45`

**Issue:** The test titled "구분자가 필드 내부에 포함된 줄을 경고로 표시" (line 35) only asserts `expect(result.success?).to be true` — it never asserts that any warning was present on the card. Combined with CR-01 (the collision check is dead code), this test passes for the wrong reason and provides no protection against regression. Even after CR-01 is fixed, the assertion gap remains.

**Fix:**
```ruby
it "구분자가 필드 내부에 포함된 줄을 경고로 표시" do
  # 5 columns for tab separator means col 5 is excess — warns about separator collision
  text = "앞면\t뒷면\t힌트\t태그\t초과열"
  result = described_class.call(text: text, separator: "\t", deck: deck, mode: :preview)

  expect(result.success?).to be true
  expect(result.preview_cards.first.warnings).to include(match(/구분자 충돌/))
  expect(result.preview_cards.first.importable?).to be false
end
```

---

### WR-06: Unauthenticated Test Placed Inside Authenticated Context

**File:** `spec/requests/cards_spec.rb:21-26`

**Issue:** The example `"비인증 시 redirect"` (line 21) lives inside the `context "인증된 본인 덱에 카드 생성"` block which has `before { sign_in(user) }`. The test calls `sign_out` immediately, which works, but the structure is misleading: the context name says "authenticated owner" but the test exercises the unauthenticated path. Future readers may not notice `sign_out` and assume the before-hook is in effect. This can cause incorrect test grouping in failure output.

**Fix:** Move the unauthenticated test into its own context at the `describe "POST /decks/:deck_id/cards"` level, without the `sign_in` before-hook:

```ruby
context "비인증 사용자" do
  it "비인증 시 로그인 페이지로 리다이렉트" do
    post deck_cards_path(deck),
      params: { card: { front: "앞면", back: "뒷면" } }
    expect(response).to redirect_to(new_session_path)
  end
end
```

---

## Info

### IN-01: `decode_separator` Passes Arbitrary User Input Through

**File:** `app/controllers/cards/imports_controller.rb:42-44`

**Issue:** The `else` branch of `decode_separator` returns `raw.to_s` unmodified. A user who manually crafts a POST request with `separator="\n"` or `separator=" "` gets that literal string used as the split delimiter. This is not an injection vector (it's a plain Ruby `String#split`, not regex or eval), but it could produce surprising parse results (e.g., `"\n"` as separator splits on nothing useful since lines are pre-split on newlines, yielding single-element arrays for every line). There is no user-facing control for this, so exploitation requires a crafted request.

**Fix (optional):** Add a whitelist guard in `decode_separator` to reject unrecognized values:

```ruby
def decode_separator(raw)
  case raw
  when "tab", "\\t" then "\t"
  when "pipe"       then "|"
  when "dash"       then "=="
  when "comma"      then ","
  else
    failure_flash_or_nil  # or simply: raise Pundit::NotAuthorizedError
    "\t"  # safe default
  end
end
```

Alternatively, validate `params[:separator]` against the allowed set before calling the service.

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
