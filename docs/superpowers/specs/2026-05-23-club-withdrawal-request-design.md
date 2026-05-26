# Club Withdrawal Request Feature

**Date:** 2026-05-23
**Status:** Approved

## Summary

Allow approved club members to submit a withdrawal request (with optional reason) that club managers must explicitly approve, rather than allowing immediate self-removal. This mirrors the existing join-request approval flow.

## Data Model

### ClubMembership changes

Add `withdrawal_requested: 3` to the status enum (integer, no breaking migration needed).
Add `withdrawal_reason` column (string, nullable) for the optional reason.

```
ClubMembership.status values:
  pending:              0  (join request awaiting approval)
  approved:             1  (active member)
  rejected:             2  (join request rejected)
  withdrawal_requested: 3  (withdrawal pending manager approval)
```

## User Flows

### Member — Club Show Page

- **Approved member**: sees "클럽탈퇴 신청" button
  - Click → opens modal with optional textarea for reason
  - Submit → PATCH club_club_membership with status: withdrawal_requested
  - After submit: button replaced with "탈퇴 신청 중" badge + "신청 취소" button
- **Withdrawal-requested member**: sees "탈퇴 신청 중" badge + "신청 취소" button
  - Cancel → PATCH with status: approved (reverts to normal member)
- **Pending member**: no withdrawal button (can't withdraw before being approved)

### Manager — Club Manage Page

New section "탈퇴 신청" (shown only when any exist), styled with red/danger border matching the urgency, similar to the existing "가입 신청 대기" yellow section.

Columns: 닉네임 | 이메일 | 탈퇴 사유 | 신청일 | 액션

- **승인** button → DELETE membership (member leaves)
- **거절** button → PATCH status back to approved (member stays)

## Authorization (Pundit)

`ClubMembershipPolicy`:

| Action | Who |
|--------|-----|
| `create?` | any authenticated user |
| `update?` | manager OR (self AND changing own status between approved ↔ withdrawal_requested) |
| `destroy?` | self OR manager |

## Controller

`ClubMembershipsController#update` handles all status transitions:
- Member calling with `status: withdrawal_requested` or `status: approved` — allowed when it's their own record
- Manager calling with any status or role — already allowed

Withdrawal approval (destroy) re-uses the existing `destroy` action.

## Routes

No new routes needed. All actions use existing REST routes:
- `PATCH /clubs/:club_id/club_memberships/:id` — withdrawal request / cancel / reject
- `DELETE /clubs/:club_id/club_memberships/:id` — withdrawal approval

## Migration

```ruby
add_column :club_memberships, :withdrawal_reason, :string
# No migration needed for enum value addition (integer-backed)
```

## Files to Change

| File | Change |
|------|--------|
| `db/migrate/...add_withdrawal_reason_to_club_memberships.rb` | New migration |
| `app/models/club_membership.rb` | Add enum value + column |
| `app/policies/club_membership_policy.rb` | Allow self status change |
| `app/controllers/club_memberships_controller.rb` | Permit withdrawal_reason param |
| `app/views/clubs/show.html.erb` | Add withdrawal button/modal/badge |
| `app/views/clubs/manage.html.erb` | Add withdrawal requests section |
| `spec/models/club_membership_spec.rb` | Test new enum value |
| `spec/policies/club_membership_policy_spec.rb` | Test new policy rules |
