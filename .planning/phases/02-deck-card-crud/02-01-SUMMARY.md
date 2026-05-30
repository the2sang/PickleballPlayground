---
phase: 02-deck-card-crud
plan: "01"
subsystem: test-infrastructure
tags:
  - routes
  - rspec
  - spec-stubs
  - wave-0
  - test-infra
dependency_graph:
  requires: []
  provides:
    - "config/routes.rb → decks + nested cards + cards/imports"
    - "spec/support/request_helpers.rb → sign_in(user) helper for request specs"
    - "spec/support/system_test_helpers.rb → Capybara rack_test + headless_chrome config"
    - "spec/requests/decks_spec.rb → 10 pending examples (Wave 1 target)"
    - "spec/requests/cards_spec.rb → 6 pending examples (Wave 2 target)"
    - "spec/requests/cards/imports_spec.rb → 5 pending examples (Wave 3 target)"
    - "spec/services/flashcards/paste_import_service_spec.rb → 8 pending examples (Wave 3 target)"
    - "spec/system/deck_authoring_spec.rb → 1 pending example (Wave 2 target)"
  affects:
    - "Wave 1/2/3 executors — spec stubs define acceptance criteria"
tech_stack:
  added: []
  patterns:
    - "pending(...); raise pattern for RED state spec stubs"
    - "type: :request / type: :system explicit annotation (infer_spec_type disabled)"
    - "namespace :cards { resource :imports } for singular paste-import resource"
key_files:
  created:
    - config/routes.rb (modified — deck routes added)
    - spec/support/system_test_helpers.rb
    - spec/requests/decks_spec.rb
    - spec/requests/cards_spec.rb
    - spec/requests/cards/imports_spec.rb
    - spec/services/flashcards/paste_import_service_spec.rb
    - spec/system/deck_authoring_spec.rb
  modified:
    - config/routes.rb
decisions:
  - "request_helpers.rb was pre-existing in worktree base commit (Phase 1 already created it) — verified content correct, no change needed"
  - "paste_import_service_spec.rb uses string describe (not class constant) because Flashcards::PasteImportService does not exist until Wave 3"
  - "pending(...); raise pattern used (not empty body) to prevent false-PASS on pending examples"
  - "infer_spec_type_from_file_location! remains commented — consistent with Phase 1 Deviation #2"
metrics:
  duration: "~12 minutes"
  completed: "2026-05-30T01:09:39Z"
  tasks_completed: 3
  files_modified: 7
---

# Phase 02 Plan 01: Test Infrastructure (Wave 0) Summary

Wave 0 test infrastructure for Phase 2 deck/card CRUD. Routes, spec helpers, and 5 pending spec stubs are now in place so Wave 1/2/3 executors can run `bundle exec rspec` immediately against real acceptance criteria.

## What Was Built

### Routes Added (`config/routes.rb`)

```
GET    /decks                              decks#index
POST   /decks                              decks#create
GET    /decks/new                          decks#new
GET    /decks/:id/edit                     decks#edit
GET    /decks/:id                          decks#show
PATCH  /decks/:id                          decks#update
DELETE /decks/:id                          decks#destroy
GET    /decks/:deck_id/cards/new           cards#new
POST   /decks/:deck_id/cards               cards#create
GET    /decks/:deck_id/cards/:id/edit      cards#edit
PATCH  /decks/:deck_id/cards/:id           cards#update
DELETE /decks/:deck_id/cards/:id           cards#destroy
GET    /decks/:deck_id/cards/imports/new   cards/imports#new
POST   /decks/:deck_id/cards/imports       cards/imports#create
```

16 routes total. No shallow — `Cards::ImportsController` requires `deck_id` explicitly.

### Spec Support Helpers

| File | Content |
|------|---------|
| `spec/support/request_helpers.rb` | `sign_in(user)` — POSTs to `session_path` with `email_address` + `"password"` |
| `spec/support/system_test_helpers.rb` | `driven_by :rack_test` (default) + `driven_by :selenium, using: :headless_chrome` (js: true) |

Both files auto-loaded via `Rails.root.glob('spec/support/**/*.rb')` in `rails_helper.rb` (line 26).

### Spec Stubs Created

| File | Pending Examples | Wave Target |
|------|-----------------|-------------|
| `spec/requests/decks_spec.rb` | 10 | Wave 1 |
| `spec/requests/cards_spec.rb` | 6 | Wave 2 |
| `spec/requests/cards/imports_spec.rb` | 5 | Wave 3 |
| `spec/services/flashcards/paste_import_service_spec.rb` | 8 | Wave 3 |
| `spec/system/deck_authoring_spec.rb` | 1 | Wave 2 |

All 30 examples: pending, 0 failures (`bundle exec rspec --dry-run`).

### Phase 1 Deviation #2 Maintained

`config.infer_spec_type_from_file_location!` remains commented in `spec/rails_helper.rb` (line 68). All spec files explicitly declare `type: :request` or `type: :system`.

### Wave 1+ Helper Signatures

```ruby
# Request spec sign-in
def sign_in(user)
  post session_path, params: { email_address: user.email_address, password: "password" }
end

# System spec driver (auto-configured via before hook)
# Non-JS: driven_by :rack_test
# JS:     driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] paste_import_service_spec.rb class constant reference**
- **Found during:** Task 3 dry-run
- **Issue:** `RSpec.describe Flashcards::PasteImportService do` raises `NameError: uninitialized constant Flashcards` because the service class doesn't exist until Wave 3
- **Fix:** Changed to `RSpec.describe "Flashcards::PasteImportService" do` (string form) — RSpec accepts this for stubs targeting future implementations
- **Files modified:** `spec/services/flashcards/paste_import_service_spec.rb`
- **Commit:** 212634f

**2. [Observation] request_helpers.rb pre-existing**
- `spec/support/request_helpers.rb` was already present in the worktree base commit (created in Phase 1)
- Content verified identical to plan spec — no change made
- Task 2 commit only adds `system_test_helpers.rb`

**3. [Observation] spec/support directory empty but exists**
- The worktree `spec/support/` directory existed but appeared empty via `ls` output (misleading — actually contained `request_helpers.rb` at git level)
- Resolved by checking `git diff` which confirmed the file existed in tracked state

## Commits

| Task | Commit | Message |
|------|--------|---------|
| Task 1 | 6c5ab26 | chore(02-01): add decks + nested cards + cards/imports routes |
| Task 2 | 6123612 | chore(02-01): add system_test_helpers.rb for Capybara driver config |
| Task 3 | 212634f | test(02-01): add 5 spec stubs for Wave 1+ implementation (RED state) |

## Self-Check: PASSED

- config/routes.rb: 16 deck-related routes confirmed
- spec/support/request_helpers.rb: FOUND
- spec/support/system_test_helpers.rb: FOUND
- spec/requests/decks_spec.rb: FOUND (10 pending)
- spec/requests/cards_spec.rb: FOUND (6 pending)
- spec/requests/cards/imports_spec.rb: FOUND (5 pending)
- spec/services/flashcards/paste_import_service_spec.rb: FOUND (8 pending)
- spec/system/deck_authoring_spec.rb: FOUND (1 pending)
- `bundle exec rspec ... --dry-run`: 91 examples, 0 failures
- `infer_spec_type_from_file_location!`: still commented
