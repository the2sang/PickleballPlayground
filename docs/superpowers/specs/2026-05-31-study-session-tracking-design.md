# Study Session Tracking Design

Date: 2026-05-31

## Problem

The flashcard hub page has no per-user study statistics on deck cards. There is no "study session" concept — only per-card SM2 records. Users cannot repeat a deck once all due cards are exhausted, and there is no results page after completing a session.

## Goals

1. Show study count and last session score on each deck card (top-right badge)
2. Allow all decks to be studied repeatedly (SM2 preserved)
3. Show a per-card correct/incorrect results page after study completion

## Approach: StudySession + StudySessionAnswer models

### New DB tables

**study_sessions**
- `user_id` (FK users)
- `deck_id` (FK decks)
- `repeat` boolean — true when started via "다시 학습하기"
- `completed_at` datetime — null while in progress
- `total_count` integer
- `correct_count` integer
- index on `[user_id, deck_id]`, `[user_id, completed_at]`

**study_session_answers**
- `study_session_id` (FK study_sessions)
- `card_id` (FK cards)
- `rating` integer 1–4 (same as SM2 rating)
- `is_correct` boolean — rating >= 3
- unique index on `[study_session_id, card_id]`

### Models

```
StudySession belongs_to :user, :deck
             has_many :study_session_answers

StudySessionAnswer belongs_to :study_session, :card
```

`StudySession#score_pct` returns `(correct_count / total_count * 100).round` or nil.

### Flow

**Study start** (`GET /decks/:id/study`):
- Delete incomplete sessions for this user+deck
- Create new StudySession
- `?repeat=true` → all deck cards; else → SM2 StudyQueueQuery

**Card submit** (`POST /card_reviews` + hidden `study_session_id`):
- SM2 update via SubmitReviewService (unchanged)
- Create StudySessionAnswer (is_correct = rating >= 3)
- Compute next card: normal → SM2 queue; repeat → deck cards not yet in this session's answers
- When all answered: complete StudySession, redirect to results page

**Results page** (`GET /decks/:deck_id/study_sessions/:id`):
- Split answers into correct / incorrect groups
- Show card front, correct answer, user's answer for incorrect cards
- "다시 학습하기" button links to `deck_study_path(deck, repeat: true)`

### Deck card badge

DecksController#index preloads per-deck stats for current user:
- Session count via `group(:deck_id).count`
- Last session via `group(:deck_id).maximum(:id)` → fetch those records

Badge displays: "N회 학습 · 마지막 Z%"

### Routes added

```ruby
resources :decks do
  resource  :study, only: %i[show], module: :decks          # existing
  resources :study_sessions, only: %i[show], module: :decks # new
end
```

## Files Changed

| New | Modified |
|-----|----------|
| db/migrate/..._create_study_sessions.rb | config/routes.rb |
| db/migrate/..._create_study_session_answers.rb | app/controllers/decks/studies_controller.rb |
| app/models/study_session.rb | app/controllers/card_reviews_controller.rb |
| app/models/study_session_answer.rb | app/controllers/decks_controller.rb |
| app/controllers/decks/study_sessions_controller.rb | app/views/decks/_deck.html.erb |
| app/views/decks/study_sessions/show.html.erb | app/views/decks/studies/_card.html.erb |
| app/policies/study_session_policy.rb | app/views/decks/studies/_complete.html.erb |
| | app/views/card_reviews/create.turbo_stream.erb |
