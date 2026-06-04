# Club Favorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 동호회 목록 페이지에서 준회원/정회원 가입 상태인 사용자가 동호회를 즐겨찾기할 수 있고, 즐겨찾기한 동호회가 목록 상단에 노출되도록 한다.

**Architecture:** `club_favorites` 테이블로 사용자-동호회 즐겨찾기 관계를 저장한다. `ClubFavoritesController`가 Turbo Stream으로 버튼을 즉각 토글하고, `ClubsController#index`는 즐겨찾기 동호회를 상단 정렬해 반환한다. 즐겨찾기 버튼은 `ClubMembership` 상태가 `pending` 또는 `approved`인 사용자에게만 노출된다.

**Tech Stack:** Rails 8.1, Turbo Streams, Pundit, SQLite3, Minitest

---

## File Map

| 역할 | 파일 |
|------|------|
| Migration | `db/migrate/TIMESTAMP_create_club_favorites.rb` |
| Model | `app/models/club_favorite.rb` (신규) |
| Model 수정 | `app/models/user.rb` — `has_many :club_favorites` 추가 |
| Model 수정 | `app/models/club.rb` — `has_many :club_favorites` 추가 |
| Policy | `app/policies/club_favorite_policy.rb` (신규) |
| Controller | `app/controllers/club_favorites_controller.rb` (신규) |
| Controller 수정 | `app/controllers/clubs_controller.rb` — `index` 정렬 로직 |
| Routes | `config/routes.rb` — `resource :favorite` 추가 |
| View — 버튼 partial | `app/views/club_favorites/_button.html.erb` (신규) |
| View — Turbo create | `app/views/club_favorites/create.turbo_stream.erb` (신규) |
| View — Turbo destroy | `app/views/club_favorites/destroy.turbo_stream.erb` (신규) |
| View 수정 | `app/views/clubs/index.html.erb` — 버튼 렌더 + DOM ID |
| Fixture | `test/fixtures/club_favorites.yml` (신규) |
| Test — Model | `test/models/club_favorite_test.rb` (신규) |
| Test — Controller | `test/controllers/club_favorites_controller_test.rb` (신규) |

---

## Task 1: Migration + ClubFavorite 모델

**Files:**
- Create: `db/migrate/TIMESTAMP_create_club_favorites.rb`
- Create: `app/models/club_favorite.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/club.rb`
- Create: `test/fixtures/club_favorites.yml`
- Create: `test/models/club_favorite_test.rb`

- [ ] **Step 1: Migration 생성**

```bash
bin/rails generate migration CreateClubFavorites user:references club:references
```

생성된 파일을 열어 unique 인덱스를 추가한다:

```ruby
class CreateClubFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :club_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :club, null: false, foreign_key: true
      t.timestamps
    end
    add_index :club_favorites, [:user_id, :club_id], unique: true
  end
end
```

- [ ] **Step 2: Migration 실행**

```bash
bin/rails db:migrate
```

Expected: `CreateClubFavorites: migrated`

- [ ] **Step 3: 테스트 작성 (RED)**

`test/models/club_favorite_test.rb`:
```ruby
require "test_helper"

class ClubFavoriteTest < ActiveSupport::TestCase
  def setup
    @user  = users(:one)
    @club  = clubs(:approved_club)
  end

  test "valid with user and club" do
    fav = ClubFavorite.new(user: @user, club: @club)
    assert fav.valid?
  end

  test "invalid without user" do
    fav = ClubFavorite.new(club: @club)
    assert_not fav.valid?
  end

  test "invalid without club" do
    fav = ClubFavorite.new(user: @user)
    assert_not fav.valid?
  end

  test "user cannot favorite same club twice" do
    ClubFavorite.create!(user: @user, club: @club)
    dup = ClubFavorite.new(user: @user, club: @club)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "이미 즐겨찾기한 동호회입니다."
  end
end
```

- [ ] **Step 4: 테스트 실행해 실패 확인**

```bash
RAILS_ENV=test bin/rails db:migrate
bin/rails test test/models/club_favorite_test.rb
```

Expected: `NameError: uninitialized constant ClubFavorite`

- [ ] **Step 5: ClubFavorite 모델 작성**

`app/models/club_favorite.rb`:
```ruby
class ClubFavorite < ApplicationRecord
  belongs_to :user
  belongs_to :club

  validates :user_id, uniqueness: { scope: :club_id, message: "이미 즐겨찾기한 동호회입니다." }
end
```

- [ ] **Step 6: User, Club 모델에 association 추가**

`app/models/user.rb` — `has_many :club_memberships` 줄 다음에 추가:
```ruby
has_many :club_favorites, dependent: :destroy
has_many :favorited_clubs, through: :club_favorites, source: :club
```

`app/models/club.rb` — `has_many :game_sessions` 줄 다음에 추가:
```ruby
has_many :club_favorites, dependent: :destroy
```

- [ ] **Step 7: Fixture 추가**

`test/fixtures/club_favorites.yml`:
```yaml
one:
  user: one
  club: approved_club
```

- [ ] **Step 8: 테스트 실행해 통과 확인**

```bash
bin/rails test test/models/club_favorite_test.rb
```

Expected: `4 runs, 4 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 9: 커밋**

```bash
git add db/migrate/ db/schema.rb app/models/club_favorite.rb app/models/user.rb app/models/club.rb test/models/club_favorite_test.rb test/fixtures/club_favorites.yml
git commit -m "feat: ClubFavorite 모델 + 마이그레이션 추가"
```

---

## Task 2: Policy + Routes + Controller

**Files:**
- Create: `app/policies/club_favorite_policy.rb`
- Modify: `config/routes.rb`
- Create: `app/controllers/club_favorites_controller.rb`
- Create: `test/controllers/club_favorites_controller_test.rb`

- [ ] **Step 1: 컨트롤러 테스트 작성 (RED)**

`test/controllers/club_favorites_controller_test.rb`:
```ruby
require "test_helper"

class ClubFavoritesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @club       = clubs(:approved_club)
    @member     = users(:one)           # approved 멤버 (fixture: manager_membership)
    @non_member = users(:two)
  end

  # two는 approved_club의 멤버가 아니므로 즐겨찾기 불가
  # (fixture club_memberships.yml에 two는 없음)
  # one은 manager_membership으로 approved 상태

  test "approved member can favorite a club" do
    sign_in_as @member
    assert_difference "ClubFavorite.count", 1 do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :ok
  end

  test "non-member cannot favorite a club" do
    sign_in_as @non_member
    assert_no_difference "ClubFavorite.count" do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :forbidden
  end

  test "unauthenticated user cannot favorite" do
    assert_no_difference "ClubFavorite.count" do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :redirect
  end

  test "member can unfavorite a club" do
    fav = ClubFavorite.create!(user: @member, club: @club)
    sign_in_as @member
    assert_difference "ClubFavorite.count", -1 do
      delete club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :ok
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

```bash
bin/rails test test/controllers/club_favorites_controller_test.rb
```

Expected: 라우팅 오류 또는 `NameError`

- [ ] **Step 3: Routes 추가**

`config/routes.rb`의 `resources :clubs do` 블록에 추가:
```ruby
resources :clubs do
  resource :favorite, only: %i[create destroy], controller: "club_favorites"
  member { get :manage }
  resources :club_memberships, only: %i[index create update destroy], shallow: false
  resources :guest_applications, only: %i[new create], path: "guest"
end
```

- [ ] **Step 4: Pundit Policy 작성**

`app/policies/club_favorite_policy.rb`:
```ruby
class ClubFavoritePolicy < ApplicationPolicy
  def create?
    return false unless user.present?
    membership = user.club_memberships.find_by(club: record.club)
    membership&.approved? || membership&.pending?
  end

  def destroy?
    user.present? && record.user == user
  end
end
```

- [ ] **Step 5: Controller 작성**

`app/controllers/club_favorites_controller.rb`:
```ruby
class ClubFavoritesController < ApplicationController
  before_action :require_authentication
  before_action :set_club

  def create
    @favorite = ClubFavorite.find_or_initialize_by(user: Current.user, club: @club)
    authorize @favorite
    @favorite.save!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path }
    end
  end

  def destroy
    @favorite = ClubFavorite.find_by!(user: Current.user, club: @club)
    authorize @favorite
    @favorite.destroy!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path }
    end
  end

  private

  def set_club = @club = Club.find(params[:club_id])
end
```

- [ ] **Step 6: 테스트 실행해 통과 확인**

```bash
bin/rails test test/controllers/club_favorites_controller_test.rb
```

Expected: `4 runs, 4 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 7: 커밋**

```bash
git add app/policies/club_favorite_policy.rb app/controllers/club_favorites_controller.rb config/routes.rb test/controllers/club_favorites_controller_test.rb
git commit -m "feat: ClubFavoritesController + Policy + Routes 추가"
```

---

## Task 3: ClubsController index 정렬 수정

**Files:**
- Modify: `app/controllers/clubs_controller.rb`

- [ ] **Step 1: index 액션 수정**

`app/controllers/clubs_controller.rb`의 `index` 액션을 아래로 교체:
```ruby
def index
  clubs = policy_scope(Club)
  if Current.user
    fav_ids = Current.user.club_favorites.pluck(:club_id)
    @member_club_ids    = Current.user.club_memberships
                                       .where(status: %i[pending approved])
                                       .pluck(:club_id).to_set
    @favorited_club_ids = fav_ids.to_set
    @clubs = if fav_ids.any?
      clubs.order(
        Arel.sql("CASE WHEN id IN (#{fav_ids.join(',')}) THEN 0 ELSE 1 END, name ASC")
      )
    else
      clubs.order(:name)
    end
  else
    @member_club_ids    = Set.new
    @favorited_club_ids = Set.new
    @clubs = clubs.order(:name)
  end
end
```

- [ ] **Step 2: 커밋**

```bash
git add app/controllers/clubs_controller.rb
git commit -m "feat: 즐겨찾기 동호회 목록 상단 정렬"
```

---

## Task 4: View — 즐겨찾기 버튼 + Turbo Stream

**Files:**
- Create: `app/views/club_favorites/_button.html.erb`
- Create: `app/views/club_favorites/create.turbo_stream.erb`
- Create: `app/views/club_favorites/destroy.turbo_stream.erb`
- Modify: `app/views/clubs/index.html.erb`

- [ ] **Step 1: 즐겨찾기 버튼 partial 작성**

`app/views/club_favorites/_button.html.erb`:
```erb
<% favorited = favorited_club_ids.include?(club.id) %>
<% can_fav   = member_club_ids.include?(club.id) %>

<% if can_fav %>
  <% if favorited %>
    <%= button_to club_favorite_path(club),
          method: :delete,
          class: "cl-fav-btn cl-fav-btn--active",
          title: "즐겨찾기 해제",
          data: { turbo_stream: true } do %>
      <iconify-icon icon="lucide:star" width="15" style="color:#f59e0b;"></iconify-icon>
    <% end %>
  <% else %>
    <%= button_to club_favorite_path(club),
          method: :post,
          class: "cl-fav-btn",
          title: "즐겨찾기",
          data: { turbo_stream: true } do %>
      <iconify-icon icon="lucide:star" width="15"></iconify-icon>
    <% end %>
  <% end %>
<% end %>
```

> **Note:** `favorited_club_ids`와 `member_club_ids`는 컨트롤러에서 `@favorited_club_ids`, `@member_club_ids`로 설정되고, index 뷰에서 로컬 변수로 전달된다.

- [ ] **Step 2: Turbo Stream 템플릿 작성**

`app/views/club_favorites/create.turbo_stream.erb`:
```erb
<%= turbo_stream.replace "club-fav-#{@club.id}" do %>
  <%= render "club_favorites/button",
        club: @club,
        favorited_club_ids: (Current.user.club_favorites.pluck(:club_id).to_set),
        member_club_ids: (Current.user.club_memberships.where(status: %i[pending approved]).pluck(:club_id).to_set) %>
<% end %>
```

`app/views/club_favorites/destroy.turbo_stream.erb`:
```erb
<%= turbo_stream.replace "club-fav-#{@club.id}" do %>
  <%= render "club_favorites/button",
        club: @club,
        favorited_club_ids: (Current.user.club_favorites.pluck(:club_id).to_set),
        member_club_ids: (Current.user.club_memberships.where(status: %i[pending approved]).pluck(:club_id).to_set) %>
<% end %>
```

- [ ] **Step 3: clubs/index.html.erb 카드에 버튼 DOM + 렌더링 추가**

`app/views/clubs/index.html.erb`의 `<%= link_to club_path(club), class: "cl-card" do %>` 블록을 아래로 교체:

```erb
<div class="cl-card-wrapper">
  <div id="club-fav-<%= club.id %>" class="cl-card__fav">
    <%= render "club_favorites/button",
          club: club,
          favorited_club_ids: @favorited_club_ids,
          member_club_ids: @member_club_ids %>
  </div>
  <%= link_to club_path(club), class: "cl-card" do %>
    <div class="cl-card__top">
      <div class="cl-card__icon">
        <iconify-icon icon="lucide:users" width="16"></iconify-icon>
      </div>
      <span class="cl-badge cl-badge--neutral">회원 <%= club.club_memberships.approved.count %>명</span>
    </div>
    <p class="cl-card__name"><%= club.name %></p>
    <p class="cl-card__desc"><%= club.description.presence || "소개가 없습니다." %></p>
  <% end %>
</div>
```

- [ ] **Step 4: 즐겨찾기 버튼 CSS 추가**

즐겨찾기 버튼용 최소 스타일이 필요하다. 프로젝트의 기존 CSS 파일 위치를 확인한다:

```bash
ls app/assets/stylesheets/
```

`application.css` (또는 프로젝트 메인 CSS 파일)에 추가:
```css
.cl-card-wrapper {
  position: relative;
}

.cl-card__fav {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  z-index: 1;
}

.cl-fav-btn {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem;
  border-radius: 0.25rem;
  color: #9ca3af;
  line-height: 1;
}

.cl-fav-btn:hover {
  color: #f59e0b;
}

.cl-fav-btn--active {
  color: #f59e0b;
}

.cl-fav-btn form,
.cl-fav-btn input[type="submit"] {
  display: inline;
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
}
```

> **Note:** button_to는 `<form>` 태그를 생성한다. 기본 form 스타일을 override해 버튼처럼 보이도록 위 CSS가 필요하다.

- [ ] **Step 5: 서버 기동 후 수동 확인**

```bash
bin/dev
```

브라우저에서 http://localhost:3000 접속 후:
1. 로그인 → 동호회 목록 확인
2. 가입한 동호회 카드에 별 아이콘 노출 확인
3. 별 클릭 → 노란 별로 즉각 변경 (Turbo Stream) 확인
4. 페이지 새로고침 → 즐겨찾기 동호회가 상단에 노출 확인
5. 미가입 동호회에는 별 아이콘 미노출 확인
6. 비로그인 상태에서 별 미노출 확인

- [ ] **Step 6: 커밋**

```bash
git add app/views/club_favorites/ app/views/clubs/index.html.erb app/assets/
git commit -m "feat: 동호회 즐겨찾기 버튼 UI + Turbo Stream 토글"
```

---

## 완료 후 최종 커밋

```bash
git push origin main
```
