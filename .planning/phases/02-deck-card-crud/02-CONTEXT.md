---
phase: 02-deck-card-crud
created: 2026-05-29
status: ready_for_research
---

<domain>
Phase 2: Deck + Card CRUD — 인증된 사용자가 브라우저에서 개인 덱을 만들고, 단일 폼/paste import로 카드를 채우고, 행 단위 인라인 편집할 수 있다. 빠른 입력 워크플로우 + 3-tier 표시 통일이 핵심.
</domain>

<carryforward>
**From Phase 1 (Foundations) — locked, do not re-decide:**

- 스키마/마이그레이션: `decks`, `cards`, `card_reviews`, `tournament_event_decks`, ActiveStorage 모두 적용됨 (HEAD `f6536b9`).
- 모델 inverse: `User has_many :decks`, `Club has_many :decks`, `TournamentEvent has_many :tournament_event_decks` 추가됨.
- Pundit 정책 stubs (4개) — `DeckPolicy/CardPolicy/CardReviewPolicy/TournamentEventDeckPolicy`.
  - `personal_owner?` = true → 본인 personal 덱만 show/update/destroy (Phase 2가 사용할 수 있는 유일한 정책 트루스).
  - `create?` = `user.present?` → 어떤 scope든 생성 가능하지만 Phase 2는 personal만 노출.
  - `DeckPolicy::Scope#resolve` = `scope.none` (stub — 컨트롤러가 명시적으로 `owner: current_user`로 좁혀야 함, Phase 4에서 교체).
  - **TODO(phase-4) 마커 4개 + TODO(phase-5) 1개** 존재 — Phase 2 코드는 이 마커를 건드리지 않음.
- 서비스: `Flashcards::Sm2Service`, `Flashcards::ForkDeckService` 구현됨. Fork UI는 Phase 4 (Phase 2는 fork 버튼 비노출).
- 팩토리: `deck` (3 scopes traits), `card`, `card_review`, `tournament_event_deck` + lint spec green.
- 시드: `db/seeds/flashcards.yml` + loader — 3 공식 덱(피클볼 룰 30 / 영어 용어 25 / 스코어 시나리오 20), 75장 모두 `draft: true`.
- ActiveStorage: 모델 attach 선언됨 (`has_one_attached :front_image/:back_image` + content_type/size validation). UI는 Phase 2에서 완전 숨김(아래 결정 참조).

**Carryforward 단언:**
- 어떤 Phase 2 컨트롤러 액션도 `policy_scope(Deck)`를 그대로 사용 금지 — `Deck.where(owner: Current.user)` 등 명시적 스코프 사용 (정책 Scope stub이 `scope.none`이라 그대로 쓰면 빈 결과만 옴).
- `authorize @deck` 호출은 OK — `personal_owner?` 정책이 동작함. 단 `personal` 외 scope의 덱은 Phase 2에서 read-only로만 렌더 (full read auth는 Phase 4에서 클럽/공식 보호 룰 추가).
</carryforward>

<decisions>

### 1. 단일 카드 폼 키보드 UX

- **저장+다음 트리거: `Cmd+Enter`** (back 필드 포함 모든 필드에서).
- 일반 `Enter`는 textarea(back)에서 줄바꿈으로 동작 — 멀티라인 카드 안전 처리.
- 저장 성공 후: form reset, `front` 필드에 자동 포커스, 카운터 "X장 저장됨" 헤더에 표시.
- 입력 순서(`Tab`): `front → back → hint → tags`. `card_type`는 v1에서 항상 `basic` — 폼에서 hidden, 노출 안 함.
- 폼 검증 실패 시: 폼 자체는 유지하고 에러 메시지 표시 (계속 입력 가능), 카운터는 증가 안 함.
- 키보드 도움말: 폼 하단에 `Cmd+Enter`로 저장하고 다음 카드 안내 (한국어).

### 2. Paste Import UX + 안전

- **구분자 자동 감지 + 명시적 확인 + 수동 오버라이드.**
- 텍스트 붙여넣기 시: 첫 5줄 분석 → 가장 빈도 높은 구분자 추측 (Tab > Pipe `|` > Dash `==`).
- 결과를 드롭다운 selectbox에 표시: "Tab 구분자 감지됨 (X장)" — 사용자가 다른 구분자로 변경 가능.
- 미리보기 단계 (서버 사이드):
  - 빈 줄: 무시 (skip, 카운트하지 않음).
  - `front`/`back` 미달(필드 부족): 해당 줄 경고로 표시, 미리보기 테이블에서 빨강 배경, 저장 시 제외.
  - 면 내부에 구분자 포함된 경우 (예: 탭 구분자인데 front 텍스트에 탭): "구분자 충돌 감지" 경고 표시, 저장 차단 (사용자가 구분자 변경 또는 데이터 정리 후 재시도).
  - 덱 내 `front` 중복: 경고 표시(빨강), 저장 차단 (덱 내 동일 카드 방지).
- 미리보기 렌더링: 테이블 (front/back/hint/tags 열, 한 행 한 카드).
- 일괄 저장 시: 트랜잭션 안에서 모든 카드 생성, 한 건이라도 실패하면 전부 롤백.
- 서비스: `Flashcards::PasteImportService` — 적대적 입력(구분자 충돌, 빈 줄, 공백, 컨트롤 문자) 안전 처리, 결과를 `Result struct (preview_cards:, warnings:, errors:)` 형태로 반환.

### 3. /decks Hub 레이아웃

- **섹션 헤더 + 단일 스크롤 (수직).**
- 페이지 구조 (위 → 아래):
  1. 최상단: Phase 5 Hero placeholder (오늘의 due / streak 자리) — Phase 2에서는 비워두거나 "곧 만나요" 한 줄 표시.
  2. **공식 덱** 섹션 (3장 그리드).
  3. **클럽 덱** 섹션 — 소속 클럽이 있는 사용자만 표시; 0개 클럽 멤버십이면 섹션 자체 숨김.
  4. **내 덱** 섹션 (개인 덱 그리드).
- 각 섹션에 카드 0개 시: placeholder ("아직 덱이 없어요" — 내 덱 섹션 전용; 공식 덱은 항상 3개 존재함이 시드로 보장됨).
- 덱 카드 (deck preview) 항목당 표시 정보: 제목 / 카드 수 / scope 배지 (공식/클럽/개인) / 마지막 수정일.
- 학습 시작 버튼은 Phase 3, fork 버튼은 Phase 4 — 이 phase에서는 비노출.
- 정렬: 내 덱은 `updated_at DESC`; 공식 덱은 시드 순서 (position 또는 created_at).

### 4. 인라인 카드 편집 상호작용

- **행 전체 클릭 → 편집 모드 + 명시적 저장/취소.**
- 덱 상세 페이지(`/decks/:id`)의 카드 표에서 한 행 클릭 → 해당 `tr`이 Turbo Frame으로 교체 → 편집 form 렌더 (front/back/hint/tags inline).
- 편집 모드 진입 시: 다른 행 클릭 무시 (한 번에 한 행만 편집 가능), 페이지 다른 액션도 막지 않음.
- 저장 트리거: 명시적 "저장" 버튼 (Cmd+Enter 핫키도 동작).
- 취소 트리거: 명시적 "취소" 버튼 또는 `Escape` 키 → Turbo Frame이 원래 read-only 행으로 되돌아감.
- 저장 성공: Turbo Stream으로 해당 행 read-only 버전 교체 + 짧은 ("저장됨") 토스트(또는 flash).
- 저장 실패: 편집 form 유지, 에러 메시지 inline.
- Turbo Frame 범위: `<tr id="card_{id}">` 단위 — 다른 행 영향 없음.
- 삭제: 편집 모드 안에 "삭제" 버튼; 클릭 시 `confirm` 다이얼로그 → Turbo Stream으로 행 제거.

### 5. /decks 빈 상태 UX (0 덱 사용자)

- **온보딩: 공식 덱 hero + 2 CTA + 공식 덱 3개 프리뷰.**
- Hero 메시지: "낱말카드로 학습을 시작해 보세요" (한국어).
- 1차 CTA: "내 덱 만들기" → `/decks/new`.
- 2차 CTA: "붙여넣기 가져오기" → `/decks/new` (paste import 모드 활성화 또는 별도 진입점).
- Hero 아래에 공식 덱 3개 카드 프리뷰 (카드 1~2장 샘플과 함께) — 사용자가 "이런 덱을 만들면 되는구나" 즉시 학습.
- 1개 이상 덱 보유 시 hero 미노출 (3섹션 그리드만).

### 6. 이미지 첨부 필드 UI

- **완전 숨김 + form params 차단 (ROADMAP 점수 #8 조건).**
- 카드 form에 image 필드 UI 렌더링 0% — `front_image` / `back_image` input 요소 자체 없음.
- 컨트롤러 strong params에서 `front_image` / `back_image` 명시적 제외 (또는 처음부터 permit 목록에 없음).
- request spec으로 강제: "image attachment를 form params로 전송하면 422 또는 무시" 케이스 추가 — 보안 회귀 방지.
- 모델 레벨 `has_one_attached`는 그대로 유지 (Phase 5+에서 attach 가능). attach 자체는 OK, 사용자 입력 경로가 닫혀 있을 뿐.

</decisions>

<deferred>
- **이미지 업로드 UX** — v1 영구 숨김 (PROJECT.md 결정). v2 이상에서 검토.
- **Fork 버튼 UI** — Phase 4 (서비스는 Phase 1에 존재).
- **클럽 덱 생성 UX** (덱 form에서 `scope: :club` 선택) — Phase 4.
- **공식 덱 모더레이션 UI** (draft 플래그 해제) — Phase 4 또는 별도 admin Phase. 75장 draft 카드는 일단 운영자(site_admin?)가 콘솔에서 검토 후 draft 해제 예정.
- **Featured toggle** — Phase 4.
- **학습 시작 버튼 / SRS loop** — Phase 3.
- **Due-count badge / streak / mastery** — Phase 5.
- **카드 정렬/필터(`tags`별 필터)** — 사용 빈도 보고 Phase 5 또는 미루기.
</deferred>

<scope_guardrail>
**이번 phase에 들어가지 않는 것:**
- 학습 세션(SRS loop) — Phase 3.
- DeckPolicy의 3-tier resolver — Phase 4 (Phase 2는 personal만 fully writable).
- 클럽/공식 덱의 cross-user 보안 강화 — Phase 4.
- 통계 / due 카운트 / 학습 진도 — Phase 5.

**이번 phase에서 처리하는 것:**
- 인증된 사용자의 personal 덱 CRUD 전체.
- 공식·클럽 덱 read-only 렌더링 (Phase 2 임시 룰: `Deck.where(scope: :official).or(Deck.joins(:owner_club).where(owner_clubs: { id: user.club_membership_ids }))` 등 명시 스코프).
- Paste import 서비스 + UI.
- Inline card edit (Turbo Frame).
- /decks hub 3-tier 표시.
- 유틸리티 dropdown에 "낱말카드" 메뉴.
- 0 덱 사용자 온보딩 hero.
- 이미지 input 입력 경로 완전 차단.
</scope_guardrail>

<code_context>
**Reusable assets / patterns from codebase:**

- **Controllers**: `app/controllers/clubs_controller.rb` 패턴 따르기 — `before_action :resume_session`, `allow_unauthenticated_access only:` (필요 시), `policy_scope` 대신 명시적 `Current.user` 스코프 (Phase 1 정책 Scope stub 때문).
- **Concise controller**: `ApplicationController#current_user`, `Current.user` 사용. CurrentAttributes 패턴 (CLAUDE.md).
- **Stimulus**: `app/javascript/controllers/import_form_controller.js` 단순 패턴 (`requestSubmit()`) 참고. Paste import 텍스트 입력 감지 → 자동 detect 로직은 새 컨트롤러로 작성 (`paste_import_controller.js`).
- **Turbo Frame inline edit 선례**: `app/views/memos/edit.html.erb` + `app/views/memos/_memo.html.erb` — 행 단위 교체 패턴 분석해서 카드 행에 적용.
- **Turbo Stream**: `app/views/club_memberships/create.turbo_stream.erb` — `replace` / `append` 액션 사용 사례.
- **Layout/nav**: `app/views/layouts/application.html.erb` line 172~179 — 유틸리티 dropdown 그룹에 `<%= link_to decks_path %>` 추가 (포모도로/퍼즐 옆에).
- **Empty state hero**: 기존 hero 컴포넌트가 있다면 재사용, 없으면 Tailwind utility 클래스로 직접 작성 (No ViewComponents 사용).
- **Service Result struct 패턴**: `app/services/participations/create_service.rb` — `Result = Struct.new(:success?, ..., keyword_init: true)` 형태 그대로 `PasteImportService`에 적용.

**ViewComponents 없음** — 이 프로젝트는 partials + Turbo Frame 패턴. 새 ViewComponent 도입 금지 (CLAUDE.md Convention over Configuration).
</code_context>

<canonical_refs>
- `.planning/PROJECT.md` — Active 요구사항 + 핵심 가치 + 권한 매트릭스 (Phase 4 깊이 안 들어가는 한 Phase 2도 honor).
- `.planning/REQUIREMENTS.md` — F2-* 요구사항 ID (planner가 plan frontmatter에 매핑할 것).
- `.planning/ROADMAP.md` lines 89~140 — Phase 2 success criteria 8개 + suggested test surface.
- `.planning/phases/01-foundations/01-01-PLAN.md` — Phase 1에서 잠긴 인터페이스(특히 정책 stub, 모델 enum/validations).
- `.planning/phases/01-foundations/01-01-SUMMARY.md` — Phase 1 deliverables 실제 결과.
- `.planning/phases/01-foundations/01-VERIFICATION.md` — Phase 1 must_haves 검증 결과 (8/8).
- `.planning/research/PITFALLS.md` — 특히 §8 (deck-show secondary check, Phase 4에서 처리하므로 Phase 2는 personal만 안전하게).
- `docs/adr/0001-flashcard-cardreview-shared-cards.md` — 카드 cascade 룰 (Phase 2 delete 동작에 영향: 카드 삭제 시 CardReview cascade는 Phase 1에서 이미 보장).
- `CONTEXT.md` (repo root) — 도메인 글로서리.
- `.claude/rules/principles.md`, `.claude/rules/cli.md` — 코딩 표준 (KISS, YAGNI, Skinny Everything).

**Phase 2 specific code precedents (researcher가 분석):**
- `app/controllers/clubs_controller.rb` — 3-tier 표시(가입/즐겨찾기) 패턴.
- `app/controllers/comments_controller.rb` — Turbo Stream 응답 패턴.
- `app/views/memos/` — inline edit Turbo Frame 패턴.
- `app/javascript/controllers/import_form_controller.js`, `team_rows_controller.js` — 동적 폼 패턴.
- `app/views/layouts/application.html.erb` — nav 진입점.
</canonical_refs>

<open_questions>
연구/계획 단계에서 추가 확인이 필요한 항목:

1. **Paste import 트랜잭션 크기**: 한 번에 최대 몇 장까지? PROJECT.md/요구사항에 명시 없음. Researcher가 기존 import 패턴 (예: tournament import) 참고해서 기본값 제안 (예: 200/500/1000) — planner 단계에서 결정.
2. **`/decks/:id/study` 진입 버튼**: Phase 3에서 추가 예정 — 이 phase에서는 placeholder 처리 vs 완전 비노출? (현재 결정: 완전 비노출, Phase 3에서 도입.)
3. **모바일 키보드**: Cmd+Enter는 데스크탑 표준 — 모바일(스마트폰)에서 동등한 트리거? Planner가 viewport별 분기 결정 (예: 모바일은 "저장하고 다음" 버튼 더 크게).
4. **Empty 클럽 섹션 정확한 트리거**: 클럽 멤버십이 있지만 클럽 덱이 0개 vs 클럽 멤버십 0개 — 두 경우 모두 섹션 숨김 vs 멤버십 있을 때만 placeholder?

Researcher가 위 4건에 대해 권장안을 제출하고 planner가 확정.
</open_questions>
