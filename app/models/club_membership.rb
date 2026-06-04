class ClubMembership < ApplicationRecord
  belongs_to :club
  belongs_to :user

  enum :role,   { member: 0, manager: 1 }, default: :member
  enum :status, { pending: 0, approved: 1, rejected: 2, withdrawal_requested: 3 }, default: :pending

  validates :club_id, uniqueness: { scope: :user_id, message: "이미 가입 신청한 클럽입니다." }
end
