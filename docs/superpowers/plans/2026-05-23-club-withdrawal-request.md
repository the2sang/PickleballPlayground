# Club Withdrawal Request Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow approved club members to submit a withdrawal request (with optional reason) that club managers must approve, mirroring the existing join-request approval flow.

**Architecture:** Add `withdrawal_requested: 3` to `ClubMembership` status enum and `withdrawal_reason` string column. Controller uses `assign_attributes` → `authorize` → `save!` pattern so Pundit's dirty tracking (`status_was`) is available in the policy at authorization time. Policy extended to allow members to change their own status between `approved` ↔ `withdrawal_requested`.

**Tech Stack:** Rails 8.1, SQLite3, Pundit, Hotwire (Turbo), Tailwind CSS, RSpec + FactoryBot

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `db/migrate/TIMESTAMP_add_withdrawal_reason_to_club_memberships.rb` | Create | Add `withdrawal_reason` column |
| `app/models/club_membership.rb` | Modify | Add `withdrawal_requested: 3` enum value + scope |
| `app/policies/club_membership_policy.rb` | Modify | Allow member to toggle own withdrawal status |
| `app/controllers/club_memberships_controller.rb` | Modify | Permit `withdrawal_reason` param |
| `app/views/clubs/show.html.erb` | Modify | Withdrawal button/modal/badge for approved members |
| `app/views/clubs/manage.html.erb` | Modify | Withdrawal requests section with approve/reject |
| `spec/models/club_membership_spec.rb` | Create | Test new enum value and scope |
| `spec/policies/club_membership_policy_spec.rb` | Create | Test policy rules for withdrawal |

---

### Task 1: Add `withdrawal_reason` column via migration

**Files:**
- Create: `db/migrate/TIMESTAMP_add_withdrawal_reason_to_club_memberships.rb`

- [ ] **Step 1: Generate the migration**

```bash
cd /Users/the2sang/RubymineProjects/PBPlayground
bin/rails generate migration AddWithdrawalReasonToClubMemberships withdrawal_reason:string
```

Expected: `db/migrate/YYYYMMDDHHMMSS_add_withdrawal_reason_to_club_memberships.rb` created.

- [ ] **Step 2: Run the migration**

```bash
bin/rails db:migrate
```

Expected: `== AddWithdrawalReasonToClubMemberships: migrating ====`

- [ ] **Step 3: Verify schema**

```bash
grep -A 12 "create_table \"club_memberships\"" db/schema.rb
```

Expected: `t.string "withdrawal_reason"` line present.

- [ ] **Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add withdrawal_reason column to club_memberships"
```

---

### Task 2: Update ClubMembership model

**Files:**
- Modify: `app/models/club_membership.rb`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/club_membership_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ClubMembership, type: :model do
  describe "enum :status" do
    it "includes withdrawal_requested" do
      membership = build(:club_membership, status: :withdrawal_requested)
      expect(membership.withdrawal_requested?).to be true
      expect(membership.status_before_type_cast).to eq 3
    end
  end

  describe ".withdrawal_requested scope" do
    it "returns only withdrawal_requested memberships" do
      approved   = create(:club_membership, status: :approved)
      withdrawal = create(:club_membership, status: :withdrawal_requested)
      expect(ClubMembership.withdrawal_requested).to include(withdrawal)
      expect(ClubMembership.withdrawal_requested).not_to include(approved)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/models/club_membership_spec.rb -f doc
```

Expected: FAIL — `ArgumentError: '3' is not a valid status` or similar.

- [ ] **Step 3: Update the model**

Replace `app/models/club_membership.rb` with:

```ruby
class ClubMembership < ApplicationRecord
  belongs_to :club
  belongs_to :user

  enum :role,   { member: 0, manager: 1 }, default: :member
  enum :status, { pending: 0, approved: 1, rejected: 2, withdrawal_requested: 3 }, default: :pending

  validates :club_id, uniqueness: { scope: :user_id, message: "이미 가입 신청한 클럽입니다." }
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/models/club_membership_spec.rb -f doc
```

Expected: 2 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/models/club_membership.rb spec/models/club_membership_spec.rb
git commit -m "feat: add withdrawal_requested status to ClubMembership"
```

---

### Task 3: Update ClubMembershipPolicy

**Files:**
- Modify: `app/policies/club_membership_policy.rb`

- [ ] **Step 1: Write the failing policy spec**

Create `spec/policies/club_membership_policy_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ClubMembershipPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:member_user)  { create(:user) }
  let(:other)        { create(:user) }
  let(:club)         { create(:club, owner: owner) }

  let(:manager_membership) do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end
  let(:member_membership) do
    create(:club_membership, club: club, user: member_user, role: :member, status: :approved)
  end

  before { manager_membership; member_membership }

  def policy(user, record) = described_class.new(user, record)

  describe "#update?" do
    context "매니저가 다른 회원의 멤버십 수정" do
      it "허용" do
        expect(policy(manager_user, member_membership).update?).to be true
      end
    end

    context "회원이 자신의 멤버십을 withdrawal_requested로 변경 요청" do
      before { member_membership.status = :withdrawal_requested }

      it "본인은 허용" do
        expect(policy(member_user, member_membership).update?).to be true
      end

      it "타인은 거부" do
        expect(policy(other, member_membership).update?).to be false
      end
    end

    context "회원이 자신의 멤버십을 approved로 되돌리기 (신청 취소)" do
      before do
        member_membership.update!(status: :withdrawal_requested)
        member_membership.status = :approved
      end

      it "본인은 허용" do
        expect(policy(member_user, member_membership).update?).to be true
      end
    end

    context "비로그인" do
      it "거부" do
        expect(policy(nil, member_membership).update?).to be false
      end
    end
  end

  describe "#destroy?" do
    it "본인 탈퇴 허용" do
      expect(policy(member_user, member_membership).destroy?).to be true
    end

    it "매니저 강제 탈퇴 허용" do
      expect(policy(manager_user, member_membership).destroy?).to be true
    end

    it "타인 거부" do
      expect(policy(other, member_membership).destroy?).to be false
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/policies/club_membership_policy_spec.rb -f doc
```

Expected: FAIL on "본인은 허용" examples — policy currently only allows managers to update.

- [ ] **Step 3: Update the policy**

Replace `app/policies/club_membership_policy.rb` with:

```ruby
class ClubMembershipPolicy < ApplicationPolicy
  def create? = user.present?

  def update?
    return false unless user.present?
    return true if club_manager?(record.club)
    # Member may toggle their own withdrawal status
    return true if user == record.user && withdrawal_status_change?
    false
  end

  def destroy?
    user.present? && (user == record.user || club_manager?(record.club))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def withdrawal_status_change?
    allowed = %w[approved withdrawal_requested]
    allowed.include?(record.status_was) && allowed.include?(record.status)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/policies/club_membership_policy_spec.rb -f doc
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/policies/club_membership_policy.rb spec/policies/club_membership_policy_spec.rb
git commit -m "feat: allow members to toggle own withdrawal status in policy"
```

---

### Task 4: Update ClubMembershipsController

**Files:**
- Modify: `app/controllers/club_memberships_controller.rb`

- [ ] **Step 1: Update controller — assign_attributes before authorize**

The key change: build `attrs` first, call `assign_attributes`, THEN `authorize`. This makes dirty tracking (`status_was`) available in the policy at authorization time.

Replace `app/controllers/club_memberships_controller.rb` with:

```ruby
class ClubMembershipsController < ApplicationController
  before_action :set_club

  def index
    @membership = ClubMembership.new(club: @club)
    authorize @membership
    @pending  = @club.club_memberships.pending.includes(:user)
    @approved = @club.club_memberships.approved.includes(:user)
  end

  def create
    @membership = @club.club_memberships.build(user: Current.user)
    authorize @membership
    if @membership.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @club, notice: "가입 신청이 완료되었습니다." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("club-join-#{@club.id}", partial: "club_memberships/join_error", locals: { club: @club, errors: @membership.errors.full_messages }) }
        format.html { redirect_to @club, alert: @membership.errors.full_messages.join(", ") }
      end
    end
  end

  def update
    @membership = ClubMembership.find(params[:id])
    attrs = {}
    attrs[:status]            = params[:status]            if params[:status].present?
    attrs[:role]              = params[:role]              if params[:role].present?
    attrs[:withdrawal_reason] = params[:withdrawal_reason] if params[:withdrawal_reason].present?
    @membership.assign_attributes(attrs)  # assign BEFORE authorize so policy sees dirty state
    authorize @membership
    @membership.save!
    redirect_back_or_to manage_club_path(@membership.club), notice: "변경되었습니다."
  end

  def destroy
    @membership = ClubMembership.find(params[:id])
    authorize @membership
    @membership.destroy!
    redirect_back_or_to clubs_path, notice: "탈퇴 처리되었습니다."
  end

  private

  def set_club = @club = Club.find(params[:club_id])
end
```

- [ ] **Step 2: Smoke-test via request (manual)**

Start server and verify no errors:
```bash
bin/rails runner "puts ClubMembership.withdrawal_requested.count"
```

Expected: `0` (no errors).

- [ ] **Step 3: Commit**

```bash
git add app/controllers/club_memberships_controller.rb
git commit -m "feat: permit withdrawal_reason param in club_memberships update"
```

---

### Task 5: Club show page — withdrawal button, modal, badge

**Files:**
- Modify: `app/views/clubs/show.html.erb`

The turbo-frame `club-join-<%= @club.id %>` currently shows the join button when no membership exists. We extend it to also show withdrawal UI when the member is approved or withdrawal_requested.

- [ ] **Step 1: Update the turbo-frame block in show.html.erb**

Find the turbo-frame block (lines 18-82 in the current file). Replace the entire `<turbo-frame id="club-join-...">` block:

```erb
<turbo-frame id="club-join-<%= @club.id %>">
  <% membership = Current.user&.club_memberships&.find_by(club: @club) %>

  <% if membership&.approved? %>
    <%# 승인된 회원: 탈퇴 신청 버튼 %>
    <div style="margin-top:12px;">
      <div data-controller="modal">
        <button type="button"
                class="btn btn--ghost btn--sm"
                style="color:var(--hcp-danger); border-color:var(--hcp-danger);"
                data-action="click->modal#open">
          <iconify-icon icon="lucide:log-out" width="13"></iconify-icon>
          클럽탈퇴 신청
        </button>

        <dialog class="club-join-dialog"
                data-modal-target="dialog"
                data-action="click->modal#backdropClose">
          <div class="club-join-dialog__inner">
            <div class="club-join-dialog__header">
              <iconify-icon icon="lucide:log-out" width="24" class="club-join-dialog__icon" style="color:var(--hcp-danger);"></iconify-icon>
              <h2 class="club-join-dialog__title">클럽 탈퇴 신청</h2>
            </div>
            <div class="club-join-dialog__body">
              <p class="club-join-dialog__lead">
                <strong><%= @club.name %></strong>에서 탈퇴를 신청합니다.<br>
                관리자 승인 후 탈퇴가 완료됩니다.
              </p>
              <%= form_with url: club_club_membership_path(@club, membership),
                            method: :patch do |f| %>
                <input type="hidden" name="status" value="withdrawal_requested">
                <div style="margin-top:12px;">
                  <%= f.label :withdrawal_reason, "탈퇴 사유 (선택)", style: "display:block; font-size:13px; font-weight:600; margin-bottom:4px;" %>
                  <%= f.text_area :withdrawal_reason,
                      name: "withdrawal_reason",
                      rows: 3,
                      placeholder: "탈퇴 사유를 입력해 주세요 (선택사항)",
                      style: "width:100%; border:1px solid var(--hcp-border); border-radius:6px; padding:8px; font-size:13px; resize:none;" %>
                </div>
                <div class="club-join-dialog__footer">
                  <button type="button"
                          class="btn btn--ghost btn--sm"
                          data-action="click->modal#close">
                    취소
                  </button>
                  <%= f.submit "탈퇴 신청",
                      class: "btn btn--sm",
                      style: "background:var(--hcp-danger); color:#fff; border:none; cursor:pointer;" %>
                </div>
              <% end %>
            </div>
          </div>
        </dialog>
      </div>
    </div>

  <% elsif membership&.withdrawal_requested? %>
    <%# 탈퇴 신청 중: 뱃지 + 신청 취소 버튼 %>
    <div style="margin-top:12px; display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
      <span class="admin-badge" style="background:#fee2e2; color:#b91c1c;">
        <iconify-icon icon="lucide:clock" width="11" style="vertical-align:-1px;"></iconify-icon>
        탈퇴 신청 중
      </span>
      <%= button_to club_club_membership_path(@club, membership),
          method: :patch,
          params: { status: "approved" },
          class: "btn btn--ghost btn--sm",
          style: "font-size:11px;" do %>
        신청 취소
      <% end %>
    </div>

  <% elsif membership.nil? %>
    <%# 비회원: 기존 가입 버튼 %>
    <div style="margin-top:12px;">
      <% if Current.user %>
        <div data-controller="modal">
          <button type="button"
                  class="btn btn--primary btn--sm"
                  data-action="click->modal#open">
            <iconify-icon icon="lucide:user-plus" width="13"></iconify-icon>
            회원가입
          </button>

          <dialog class="club-join-dialog"
                  data-modal-target="dialog"
                  data-action="click->modal#backdropClose">
            <div class="club-join-dialog__inner">
              <div class="club-join-dialog__header">
                <iconify-icon icon="lucide:shield-check" width="24" class="club-join-dialog__icon"></iconify-icon>
                <h2 class="club-join-dialog__title">동호회 가입 안내</h2>
              </div>
              <div class="club-join-dialog__body">
                <p class="club-join-dialog__lead">
                  <strong><%= @club.name %></strong>에 가입하기 전 아래 가이드를 확인해 주세요.
                </p>
                <ol class="club-join-dialog__guidelines">
                  <li>회원은 상호 존중과 배려의 자세로 활동합니다.</li>
                  <li>경기 중 공정한 플레이와 스포츠맨십을 지킵니다.</li>
                  <li>클럽 시설 및 장비를 소중히 사용하고 원상 복구합니다.</li>
                  <li>활동 일정 참석이 어려울 경우 사전에 알립니다.</li>
                  <li>클럽 내 개인 정보는 활동 목적 외에 사용하지 않습니다.</li>
                  <li>가입 후 관리자 승인이 완료되어야 활동이 가능합니다.</li>
                </ol>
              </div>
              <div class="club-join-dialog__footer">
                <button type="button"
                        class="btn btn--ghost btn--sm"
                        data-action="click->modal#close">
                  취소
                </button>
                <%= button_to club_club_memberships_path(@club),
                      method: :post,
                      class: "btn btn--primary btn--sm" do %>
                  <iconify-icon icon="lucide:check" width="13"></iconify-icon>
                  동의하고 가입하기
                <% end %>
              </div>
            </div>
          </dialog>
        </div>
      <% else %>
        <%= link_to new_registration_path(return_to: club_path(@club)), class: "btn btn--primary btn--sm" do %>
          <iconify-icon icon="lucide:user-plus" width="13"></iconify-icon>
          회원가입
        <% end %>
        <span style="font-size:11px; color:var(--hcp-cool-gray); margin-left:8px;">
          이미 계정이 있으신가요?
          <%= link_to "로그인", new_session_path(return_to: club_path(@club)),
                style: "color:var(--hcp-purple); text-decoration:underline;" %>
        </span>
      <% end %>
    </div>
  <% end %>
</turbo-frame>
```

- [ ] **Step 2: Verify the page renders (manual smoke test)**

```bash
bin/rails runner "puts 'syntax ok'"
```

Then open `http://localhost:3000/clubs/1` (adjust ID) as an approved member and verify:
- "클럽탈퇴 신청" button visible
- Clicking opens modal with optional textarea
- Submitting returns to page with "탈퇴 신청 중" badge

- [ ] **Step 3: Commit**

```bash
git add app/views/clubs/show.html.erb
git commit -m "feat: add withdrawal request button and modal to club show page"
```

---

### Task 6: Club manage page — withdrawal requests section

**Files:**
- Modify: `app/views/clubs/manage.html.erb`
- Modify: `app/controllers/clubs_controller.rb` (load withdrawal memberships)

- [ ] **Step 1: Load withdrawal_requested memberships in manage action**

In `app/controllers/clubs_controller.rb`, update the `manage` action (lines 66-72):

```ruby
def manage
  authorize @club, :manage?
  @pending_memberships             = @club.club_memberships.pending.includes(:user)
  @approved_memberships            = @club.club_memberships.approved.includes(:user).order("role DESC")
  @withdrawal_requested_memberships = @club.club_memberships.withdrawal_requested.includes(:user)
  @game_sessions                   = @club.game_sessions.order(scheduled_date: :desc).limit(20)
  @guest_applications              = @club.guest_applications.order(created_at: :desc)
end
```

- [ ] **Step 2: Add withdrawal requests section to manage view**

In `app/views/clubs/manage.html.erb`, insert the following section **after** the `@pending_memberships` section (after line 108) and **before** the `회원 관리` section:

```erb
<%# ── 탈퇴 신청 ──────────────────────────────────── %>
<% if @withdrawal_requested_memberships.any? %>
  <section class="admin-panel" style="border-color:#fca5a5; margin-bottom:16px;">
    <div class="admin-panel__header">
      <h2 class="admin-panel__title">
        <iconify-icon icon="lucide:log-out" style="color:#dc2626; vertical-align:-2px;"></iconify-icon>
        탈퇴 신청
      </h2>
      <span class="admin-badge" style="background:#fee2e2; color:#b91c1c;"><%= @withdrawal_requested_memberships.count %></span>
    </div>
    <table class="admin-table">
      <thead>
        <tr><th>닉네임</th><th>이메일</th><th>탈퇴 사유</th><th>신청일</th><th></th></tr>
      </thead>
      <tbody>
        <% @withdrawal_requested_memberships.each do |m| %>
          <tr>
            <td style="font-weight:600;"><%= m.user.nickname %></td>
            <td class="admin-table__mono"><%= m.user.email_address %></td>
            <td style="max-width:180px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; color:var(--hcp-mid-gray);">
              <%= m.withdrawal_reason.presence || "-" %>
            </td>
            <td class="admin-table__mono"><%= m.updated_at.strftime("%Y-%m-%d") %></td>
            <td style="text-align:right; display:flex; gap:6px; justify-content:flex-end;">
              <%# 승인: 멤버십 삭제 %>
              <%= button_to club_club_membership_path(@club, m),
                  method: :delete,
                  class: "btn btn--sm",
                  style: "background:var(--hcp-danger); color:#fff; border:none;",
                  data: { turbo_confirm: "#{m.user.nickname}님의 탈퇴 신청을 승인하시겠습니까?" } do %>
                <iconify-icon icon="lucide:check"></iconify-icon> 승인
              <% end %>
              <%# 거절: 상태를 approved로 복구 %>
              <%= button_to club_club_membership_path(@club, m),
                  method: :patch, params: { status: "approved" },
                  class: "btn btn--ghost btn--sm" do %>
                <iconify-icon icon="lucide:x"></iconify-icon> 거절
              <% end %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </section>
<% end %>
```

- [ ] **Step 3: Verify manage page renders without errors**

```bash
bin/rails runner "puts 'syntax ok'"
```

Then visit `http://localhost:3000/clubs/1/manage` as a manager and verify:
- When no withdrawal requests: section is hidden
- After a member submits a withdrawal request: section appears with approve/reject buttons
- Approve → member removed, page reloads
- Reject → member status restored to approved, section disappears

- [ ] **Step 4: Commit**

```bash
git add app/controllers/clubs_controller.rb app/views/clubs/manage.html.erb
git commit -m "feat: show withdrawal requests in club manage dashboard"
```

---

### Task 7: Full test run and lint

- [ ] **Step 1: Run full spec suite**

```bash
bundle exec rspec spec/models/club_membership_spec.rb spec/policies/club_membership_policy_spec.rb -f doc
```

Expected: all examples pass, 0 failures.

- [ ] **Step 2: Run rubocop**

```bash
bundle exec rubocop -a app/models/club_membership.rb \
  app/policies/club_membership_policy.rb \
  app/controllers/club_memberships_controller.rb \
  app/controllers/clubs_controller.rb
```

Expected: no offenses (or auto-corrected).

- [ ] **Step 3: Final commit if rubocop made changes**

```bash
git add -p
git commit -m "style: rubocop auto-corrections for withdrawal feature"
```
