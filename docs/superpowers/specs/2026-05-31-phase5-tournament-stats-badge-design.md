# Phase 5: Tournament Linkage + Stats + Due-Count Badge — Design Spec

**Date:** 2026-05-31
**Phase:** 5 of 5 (final milestone)
**Depends on:** Phase 1 (TournamentEventDeck schema), Phase 2 (hub UI), Phase 3 (CardReview data), Phase 4 (DeckPolicy::Scope)

---

## Goal

토너먼트 종목에서 학습 덱으로 진입할 수 있고, `/decks` 허브가 살아있는 학습 진척도를 보여주며, 네비 due 카운트 배지가 사용자를 다시 끌어들인다.

---

## Wave Structure

### Wave 1: Stats Queries (순수 백엔드)

4개 Query 객체를 `app/queries/flashcards/`에 추가. 모두 `Current.user` 주입, AR 없는 순수 쿼리.

**StreakQuery**
- `call(user:)` → Integer (연속 학습 일수)
- `CardReview.where(user: user).where('updated_at >= ?', time).group("DATE(updated_at AT TIME ZONE 'Asia/Seoul')"`
- KST 자정 기준: `Time.current.in_time_zone('Seoul').to_date`
- 어제 학습이 있으면 streak 유지, 없으면 0 리셋
- Edge case: 오늘만 학습 → streak = 1; 어제+오늘 → streak = 2

**MasteryQuery**
- `call(user:, deck:)` → Float (0.0 ~ 1.0)
- `interval_days >= 21` 카드 수 / 전체 카드 수
- `deck.cards.count == 0` → `0.0` (division-by-zero 가드)
- `joins(:card_reviews).where(card_reviews: { user: user, ...})`

**TodayProgressQuery**
- `call(user:)` → `{ reviewed_today: Integer, due_remaining: Integer }`
- reviewed_today: 오늘 KST date에 업데이트된 `CardReview` 수
- due_remaining: `next_review_at <= Time.current` 인 접근 가능 덱 카드 수 (DeckPolicy::Scope 통과)

**DueForecastQuery**
- `call(user:)` → `Array<{ date: Date, count: Integer }>` (7일, 오늘 포함)
- 단일 SQL: `WHERE next_review_at BETWEEN :today AND :today+7 GROUP BY DATE(next_review_at AT TIME ZONE 'Asia/Seoul')`
- `DeckPolicy::Scope` 를 거친 접근 가능 덱 카드만 집계
- 단일 쿼리 카운트 검증 (spec에서 `query_count` 어설션)

---

### Wave 2: `/decks` Hub Stats Hero

**DecksController#index 변경:**
- `@streak = StreakQuery.call(user: Current.user)`
- `@today_progress = TodayProgressQuery.call(user: Current.user)`
- `@due_forecast = DueForecastQuery.call(user: Current.user)`
- 마스터리는 덱 카드 파셜에서 `MasteryQuery.call(user:, deck:)` 인라인 호출 (캐시 없이 직접)

**`/decks` 허브 hero 레이아웃 (authenticated + 덱 보유 시):**

```
[ 🔥 N일 연속 ]  [ 오늘 X/Y 완료 ]  [ D+7 예상 ]
─────────────────────────────────────────────────
7일 예상 막대 차트 (Tailwind h- utility, 7컬럼 grid)
─────────────────────────────────────────────────
덱 목록 (각 카드에 마스터리 % 인라인)
```

**7일 막대 차트 구현:**
- `<div class="grid grid-cols-7 gap-1 h-16">`
- 각 컬럼: `<div style="height: <%= pct %>%">` (max count 기준 정규화)
- 라이브러리 없음, 순수 Tailwind + inline style height %

**마스터리 % 표시:**
- 덱 카드 파셜 `_deck.html.erb`에 `MasteryQuery` 호출
- `<span>마스터리 <%= (mastery * 100).round %>%</span>`
- 0% (신규) 일 때는 미표시

---

### Wave 3: Solid Cache Due Badge

**DueCountCacheService** (`app/services/flashcards/due_count_cache_service.rb`):
```ruby
class Flashcards::DueCountCacheService
  CACHE_KEY = ->(user_id) { "flashcards/due_count/#{user_id}" }
  TTL = 1.hour

  def self.fetch(user)
    Rails.cache.fetch(CACHE_KEY.call(user.id), expires_in: TTL) do
      TodayProgressQuery.call(user: user)[:due_remaining]
    end
  end

  def self.invalidate(user)
    Rails.cache.delete(CACHE_KEY.call(user.id))
  end
end
```

**Invalidation 훅 (controller에서 명시, callback 아님):**
- `CardReviewsController#create` — 평가 후 즉시 invalidate
- `CardsController#create`, `#update`, `#destroy`
- `DecksController#destroy`

**네비 파셜:**
- `app/views/shared/_nav_flashcard_badge.html.erb`
- `@due_count = Flashcards::DueCountCacheService.fetch(Current.user)`
- `due_count > 0` 일 때만 배지 렌더: `<span class="badge">{{ due_count }}</span>`
- `ApplicationController before_action` 또는 레이아웃에서 `@due_count` 설정

---

### Wave 4: Tournament Linkage

**권한 설계:**
- `DeckPolicy#tournament_deck_manage?(tournament_event)` — tournament의 club manager 또는 site_admin
- `TournamentEventPolicy`에 위임하거나 `tournament_event.tournament.club`의 manager 확인

**TournamentEvents::DecksController (edit/update only):**
```
GET  /tournament_events/:tournament_event_id/decks/edit
PUT  /tournament_events/:tournament_event_id/decks
```
- edit: `@candidate_decks = Deck.official + 매핑자_소속_클럽_덱`
- update: `TournamentEventDeck.where(tournament_event: @event).destroy_all` + 재생성 (position 포함)
- 권한: `authorize @event, :manage_decks?`

**후보 덱 쿼리:**
```ruby
official_decks = Deck.official
club_decks = Current.user.clubs.manager_or_owner
              .flat_map { |c| c.decks }
@candidate_decks = (official_decks + club_decks).uniq
```
- 다른 클럽 덱 절대 포함 안 됨

**`tournament_events/_recommended_decks.html.erb`:**
- `@event.decks.ordered_by_position` 0개면 파셜 비렌더
- 각 덱: 이름, 카드 수, `/decks/:id/study` 바로 시작 링크
- "📚 이 종목 학습하기" 섹션 제목

**tournament_events/show.html.erb 업데이트:**
- hero 바로 아래 `render "tournament_events/recommended_decks"` 추가
- manager일 때만 덱 매핑 편집 링크 표시

---

## Authorization Matrix

| 행위 | site_admin | club_manager (해당 클럽) | 기타 |
|------|-----------|------------------------|------|
| 종목 덱 매핑 편집 | ✅ | ✅ | ❌ 403 |
| 후보에 다른 클럽 덱 포함 | ❌ | ❌ | — |
| 추천 덱 카드 보기 | ✅ | ✅ | ✅ |
| 덱 학습 진입 | 권한에 따라 (DeckPolicy) | — | — |

---

## Data Flow

```
CardReview 저장
  → DueCountCacheService.invalidate(user)
  → 다음 네비 렌더 시 캐시 miss → TodayProgressQuery 재실행 → 캐시 저장
  → 배지 즉시 갱신
```

---

## Test Plan

### Wave 1 Specs
- `spec/queries/flashcards/streak_query_spec.rb` — `travel_to` 23:58 KST, 자정 경계, 하루 거른 후 0 리셋
- `spec/queries/flashcards/mastery_query_spec.rb` — interval threshold, 빈 덱 0.0
- `spec/queries/flashcards/today_progress_query_spec.rb` — KST date 경계
- `spec/queries/flashcards/due_forecast_query_spec.rb` — 단일 쿼리, 7일 경계, DeckPolicy::Scope 필터

### Wave 3 Specs
- `spec/services/flashcards/due_count_cache_service_spec.rb` — fetch/invalidate, TTL
- `spec/requests/card_reviews_spec.rb` 추가: 평가 후 cache invalidate 호출 확인
- `spec/requests/decks_spec.rb` 추가: destroy 후 cache invalidate

### Wave 4 Specs
- `spec/requests/tournament_events/decks_spec.rb` — club_manager happy path, 403 (non-manager), 후보 덱 다른 클럽 미포함, position 재정렬
- `spec/requests/tournament_events_spec.rb` 추가: show 페이지 추천 덱 카드 렌더

---

## Out of Scope

- 이메일/push/Telegram 알림
- 클럽 리더보드 / 게임화
- 사용자별 타임존 설정 (KST 하드코딩)
- 차트 라이브러리 (CSS 막대만)
- TournamentEventDeck → game_session 연결

---

## Success Criteria

1. Club manager가 자기 클럽 토너먼트 종목에서 공식+자기클럽 덱 매핑, 다른 클럽 덱 미노출
2. 매핑된 종목 show에 추천 덱 카드 + `/decks/:id/study` 링크
3. `/decks` 허브에서 streak, 오늘 현황, 마스터리 %, 7일 막대 차트 렌더
4. 23:58 KST 학습 → 00:01 KST streak 유지 (travel_to spec 그린)
5. 카드 평가 후 due badge 즉시 갱신 (Solid Cache invalidate)
6. 다른 클럽 manager의 종목 매핑 시도 → 403
7. `bundle exec rspec` 그린, `bin/brakeman` 신규 경고 0
