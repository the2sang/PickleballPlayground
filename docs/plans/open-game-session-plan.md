# 구현 계획: 오픈 게임 세션 페이지 (Open Game Session)

> 출처: `오픈 게임 세션 페이지 설계.pptx` (2026-06-17 수신)
> 작성: feature-plan 스킬 · 코드는 작성하지 않음 (계획 전용)

## 핵심 결론

**새 모델을 만들지 않는다.** 이 앱에는 이미 `GameSession` + `Participation` 시스템이 완성되어 있고,
스펙 요구사항의 약 70~80%가 기존 코드로 충족된다. "오픈 게임 세션 페이지"는 기존 `GameSession`에
**필드 2개를 추가**하고 **전용 페이지(아코디언 + 12슬롯 그리드 UI)와 복사 액션을 얹는** 작업이다.

### 이미 존재하는 것 (재사용)
| 요구사항 | 기존 구현 |
|---|---|
| 클럽관리자만 등록/수정 | `GameSessionPolicy#create?` → `club_manager?(club)` (`application_policy.rb:23`) |
| 정원·대기 처리 | `Participations::CreateService` — `full?`면 `waitlisted`, 아니면 `confirmed` |
| 취소 시 대기자 자동 승급 | `Participations::CancelService#promote_waitlist` (이미 구현됨) |
| 사이트 회원이면 클럽 비회원도 신청 | `visibility: public_visibility` + `ParticipationPolicy#create?`(`profile_complete?`만 요구) |
| 모집중/마감 상태 | `GameSession.status` enum (`open`/`closed`/`cancelled`) |
| 참가 모달 / 참가자 팝오버 | `modal_controller.js`, `participant_popover_controller.js` |

### 새로 만들 것 (실제 작업)
1. `GameSession`에 `level`(enum), `court_name`(string) 추가
2. `game_session`·`participation` **팩토리 신규 작성** (현재 없음 — 모든 스펙의 선행조건)
3. 클럽 단위 **전용 페이지**: 아코디언 카드 × 코트, 각 카드에 12슬롯 그리드(정원=confirmed, 나머지=waitlist)
4. **"세션 추가"** = 마지막 세션 복사 후 초기화 액션 (관리자)
5. **참가 신청 모달**: 회원 정보 자동 채움 / 비회원은 회원가입 유도(`return_to`)
6. **Stimulus 아코디언 컨트롤러** (기존 패턴 없음 — 신규)
7. `CancelService` 동시성 보강(row lock) — 선택적 리팩터

---

## Summary
- **Complexity:** Medium (데이터 계층 대부분 존재, 작업은 UI + 소규모 모델 확장)
- **Feature Branch:** `feature/open-game-session`
- **선행 권장:** 본 계획은 PPTX 스펙 기반. 정식 게이트(`/feature-spec-review` 7/10+)는 미수행 — 아래 "확인 필요 결정사항"을 사용자와 확정 후 착수 권장.

## 확인이 필요한 결정사항 (착수 전 사용자 확인)

| # | 항목 | 권장안 | 비고 |
|---|---|---|---|
| D1 | 슬롯 번호(1~12) 순서 의미 | **암묵적 순서**(취소 제외 참가의 `created_at` 순) — `position` 컬럼 미추가 | 기존 모델과 일치, 단순. 드래그 재정렬이 필요하면 `position` 추가로 전환 |
| D2 | "마감 시 취소자 발생 경우에만 접수" | **closed = 신규 신청 불가, 취소 시 대기자 자동 승급만** | `CreateService`가 이미 `open?`만 허용 → 일치 |
| D3 | 정원 도달 시 자동 마감 여부 | **정원 초과분은 open 상태에서 waitlisted로 계속 접수**(대기자 모집), 명시적 마감은 관리자 버튼 | 목업의 "대기자 모집 중"과 일치. 자동 마감 원하면 PR4에서 콜백 추가 |
| D4 | `level` enum | **GameSession 전용 enum 신규**(`all_level` 기본 + 5단계). `User.sport_level`과 분리 | sport_level엔 `all_level` 없음 → 재사용 불가 |
| D5 | `court_count`(기존) vs `court_name`(신규) | 공존. `court_name` nullable, 오픈게임에서만 사용 | 1 GameSession = 1 코트 카드 |
| D6 | 페이지 라우트 | 클럽 중첩 전용 라우트 `clubs/:club_id/open_sessions` (레코드는 GameSession) | 클럽 단위 페이지 + 전용 UI라 분리가 깔끔 |
| D7 | "세션 추가" 복사 범위 | 날짜·시간·레벨 복사, **코트명·참가자 비움**, 신규 레코드 | |

## Gherkin 시나리오 (스펙 → 테스트 기준)

```gherkin
Feature: 오픈 게임 세션 페이지

  Scenario: 클럽관리자가 오픈 게임 세션을 등록한다
    Given 나는 "A클럽"의 클럽관리자다
    When 오픈 세션 페이지에서 날짜/시간/레벨/코트명/정원(8)을 입력하고 저장하면
    Then 12슬롯 중 8개는 정원, 4개는 대기 슬롯으로 표시된다

  Scenario: 세션 추가는 마지막 세션을 복사한다
    Given "A코트" 세션이 하나 있을 때
    When 관리자가 "세션 추가"를 누르면
    Then 날짜·시간·레벨이 복사되고 코트명과 참가자가 비워진 새 세션이 추가된다

  Scenario: 사이트 회원이 빈 슬롯에 신청한다
    Given 프로필이 완성된 로그인 회원이고 세션이 모집중이며 정원이 남았을 때
    When "모집" 슬롯을 눌러 모달에서 신청하면
    Then 해당 슬롯이 원형 아이콘(확정)으로 바뀌고 신청자 명단에 추가된다

  Scenario: 정원 초과 신청자는 대기자가 된다
    Given 정원(8)이 모두 찼고 세션이 모집중일 때
    When 9번째 회원이 신청하면
    Then 그 참가는 waitlisted 상태가 된다

  Scenario: 확정자 취소 시 대기자가 자동 승급한다
    Given 정원이 찼고 대기자가 있을 때
    When 확정 참가자 1명이 취소하면
    Then 대기 순번 1번이 confirmed로 승급된다

  Scenario: 비회원이 신청을 시도한다
    Given 비로그인 사용자일 때
    When "모집" 슬롯을 누르면
    Then 회원가입/로그인 페이지로 유도되고, 가입 후 원래 세션으로 복귀한다

  Scenario: 일반 회원에게는 관리 버튼이 숨겨진다
    Given 클럽관리자가 아닌 회원/비로그인 사용자일 때
    When 오픈 세션 페이지를 보면
    Then "세션 추가/저장/수정" 버튼은 보이지 않고 신청만 가능하다
```

## 아키텍처 개요

**생성할 컴포넌트**
- Migration: `add_level_and_court_name_to_game_sessions`
- `OpenSessionsController` (클럽 중첩, index/create + 복사)
- `OpenSessionPolicy` 또는 기존 `GameSessionPolicy` 재사용
- `Participations::PromoteService`는 불필요(CancelService에 내장됨)
- View: `open_sessions/index`, 부분 `_court_card`, `_slot_grid`, `_apply_modal`
- Stimulus: `accordion_controller.js` (신규), `modal_controller.js`(재사용)
- Factories: `game_sessions.rb`, `participations.rb`

**수정할 컴포넌트**
- `app/models/game_session.rb` — `level` enum, `court_name` 검증, `level_label`/`court_label` 헬퍼
- `app/services/participations/cancel_service.rb` — 동시성 보강(선택)
- `config/routes.rb` — `clubs` 하위에 `open_sessions` 중첩
- 회원가입/로그인 `return_to` 처리 (비회원 유도)

---

## 점진적 PR 계획

### PR #1 — 팩토리 (선행조건)
**Branch:** `feature/open-game-session-step-1-factories`
**Tasks**
1. `spec/factories/game_sessions.rb` 작성 (club 연관, 기본값, trait: `:full`, `:closed`, `:with_court`)
2. `spec/factories/participations.rb` 작성 (trait: `:waitlisted`, `:cancelled`, `:as_guest`)
3. `FactoryBot.lint` 통과 확인
**Files:** `spec/factories/game_sessions.rb`, `spec/factories/participations.rb`
**Agent:** `rspec-agent`
**검증:** `bundle exec rspec spec/factories` / 기존 모델 스펙 그린 유지

### PR #2 — 모델 확장 (level, court_name)
**Branch:** `feature/open-game-session-step-2-model`
**Tasks (TDD)**
1. **RED:** `spec/models/game_session_spec.rb`에 level enum/기본값(all_level)/court_name 검증 테스트 추가
2. Migration: `level:integer (default 0, not null)`, `court_name:string` 추가 (`migration-agent`)
3. **GREEN:** `model-agent`로 `enum level: { all_level:0, beginner:1, beginner_intermediate:2, intermediate:3, intermediate_advanced:4, advanced:5 }`, 라벨 헬퍼
4. **REFACTOR/REVIEW**
**Files:** `db/migrate/*_add_level_and_court_name_to_game_sessions.rb`, `app/models/game_session.rb`, `db/schema.rb`, `spec/models/game_session_spec.rb`
**검증:** `bin/rails db:migrate && bundle exec rspec spec/models/game_session_spec.rb`
**보안:** 마이그레이션 reversible, 기존 데이터 영향 없음(nullable/default)

### PR #3 — 취소 동시성 보강 (선택, 소규모)
**Branch:** `feature/open-game-session-step-3-cancel-lock`
**근거:** 승급 로직은 이미 존재. 단, 동시 취소 시 대기자 중복 승급 가능 → row lock 필요.
**Tasks (TDD)**
1. **RED:** 동시 취소/승급 경합 테스트 (`with_lock` 미적용 시 실패하도록)
2. **GREEN:** `CancelService#call`을 `game_session.with_lock { ... }` 트랜잭션으로 감싸기 (`service-agent`)
3. 자동 마감/재오픈을 원하면(D3) 여기서 상태 전환 추가
**Files:** `app/services/participations/cancel_service.rb`, `spec/services/participations/cancel_service_spec.rb`
**검증:** `bundle exec rspec spec/services/participations`

### PR #4 — 컨트롤러 + 라우트 + 정책
**Branch:** `feature/open-game-session-step-4-controller`
**Tasks (TDD)**
1. **RED:** `spec/requests/open_sessions_spec.rb` — index(공개), create(관리자만 201/비관리자 403), 복사 create
2. 라우트: `resources :clubs do; resources :open_sessions, only: %i[index create] end`
3. `OpenSessionsController` (`controller-agent`):
   - `index` → `@club.game_sessions` 중 오픈게임 필터 + `policy_scope`
   - `create` → 일반 신규 **또는** `copy_last`(params[:copy_from])로 마지막 세션 복사·초기화. `authorize @club, :manage_open_sessions?` 또는 `GameSessionPolicy#create?` 재사용
4. 정책: `club_manager?` 게이트 (신규 `OpenSessionPolicy` 또는 기존 정책 재사용 — D 참고)
**Files:** `config/routes.rb`, `app/controllers/open_sessions_controller.rb`, `app/policies/open_session_policy.rb`(선택), `spec/requests/open_sessions_spec.rb`
**검증:** `bundle exec rspec spec/requests/open_sessions_spec.rb`
**보안:** strong params(`level, court_name, scheduled_date, start_time, end_time, max_participants, ...`), Pundit `authorize`, 클럽 스코프 강제

### PR #5 — 뷰: 아코디언 + 코트 카드 + 12슬롯 그리드
**Branch:** `feature/open-game-session-step-5-views`
**Tasks**
1. `open_sessions/index.html.erb` — 날짜/시간 헤더 + 코트별 아코디언 목록 + 관리자 전용 "세션 추가/저장"
2. 부분: `_court_card`(레벨/코트명/정원/신청수/상태 배지/안내문), `_slot_grid`(1~12: confirmed=원형 아이콘, 빈칸=모집 버튼), `_applicant_list`(신청자 명단)
3. 관리자 버튼은 `policy(@club).create?`로 가드 (D: 비로그인/일반회원 숨김)
4. Tailwind 스타일 (`tailwind-agent`), N+1 방지 `includes(:participations)`
**Files:** `app/views/open_sessions/*`
**검증:** request spec에서 렌더 확인 + 수동 스모크
**보안:** 신청자 이름은 `display_name`/`nickname`만 노출, XSS 회피(ERB 자동 이스케이프)

### PR #6 — Stimulus 아코디언 + 신청 모달 + 비회원 유도
**Branch:** `feature/open-game-session-step-6-interactions`
**Tasks**
1. `accordion_controller.js` 신규 (shadcn accordion 거동 참고: 단일/다중 열림, aria 속성) — `stimulus-agent`
2. 빈 슬롯 "모집" → 기존 `modal_controller.js` 재사용한 신청 모달. 회원은 성별/닉네임 자동 표시 후 `Participations::CreateService` 호출(기존 participations#create 재사용)
3. 비회원: 모달 대신 로그인/회원가입으로 `return_to=open_sessions_path` 리다이렉트, 가입·프로필 완성 후 복귀
4. 성공 시 Turbo Stream으로 슬롯/명단 갱신(원형 아이콘 전환)
**Files:** `app/javascript/controllers/accordion_controller.js`, `app/views/open_sessions/_apply_modal.html.erb`, participations 컨트롤러 Turbo 응답
**검증:** 시스템 스펙(Capybara) 또는 수동 QA(`/qa`)

### PR #7 — 마감 처리 · i18n · 마무리
**Branch:** `feature/open-game-session-step-7-polish`
**Tasks**
1. 상태 배지(모집중/마감) + "대기자 안내" 문구 i18n (`config/locales/ko.yml`)
2. 빈 상태(세션 없음) UI, 마감 세션은 신청 버튼 비활성
3. 엣지: 정원 0/12 경계, 중복 신청 방지(기존 unique index 활용) 회귀 테스트
**검증:** 전체 스위트 `bundle exec rspec`, `bundle exec rubocop -a`, `bin/brakeman --no-pager`

---

## 테스트 전략
- **Models:** `GameSession.level` enum/기본값/검증, `court_name`
- **Services:** `CancelService` 승급 + 동시성, `CreateService` 정원→대기 전환(기존 + 회귀)
- **Policies:** `OpenSession`/`GameSession` — 관리자 create 허용, 비관리자/비로그인 거부
- **Requests:** index 공개, create 권한, 복사 동작
- **System(Capybara):** 슬롯 신청→원형 전환, 아코디언 열림, 비회원 가입 유도

## 보안 고려사항
- [ ] Pundit `authorize`로 관리/복사 액션 보호 (`club_manager?`)
- [ ] strong parameters로 `club_id`/소유권 변조 차단(클럽 스코프 강제)
- [ ] 참가 신청은 `profile_complete?` 게이트 유지
- [ ] 신청자 PII는 닉네임/표시명만 노출
- [ ] Turbo Stream 응답에서 권한 재확인(관리 버튼 주입 방지)
- [ ] 동시 취소/신청 경합 → row lock (PR#3)

## 참고
- 스펙의 shadcn accordion(React)은 본 앱에선 Stimulus + Tailwind로 구현 (Hotwire 원칙)
- `court_count`(기존)와 `court_name`(신규)는 공존 — 오픈게임은 카드 1개=코트 1개
