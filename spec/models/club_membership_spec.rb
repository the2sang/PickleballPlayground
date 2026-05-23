require "rails_helper"

RSpec.describe ClubMembership, type: :model do
  describe "enum :status" do
    it "withdrawal_requested 값 포함" do
      membership = build(:club_membership, status: :withdrawal_requested)
      expect(membership.withdrawal_requested?).to be true
      expect(ClubMembership.statuses[:withdrawal_requested]).to eq 3
    end
  end

  describe ".withdrawal_requested scope" do
    it "withdrawal_requested 상태만 반환" do
      approved   = create(:club_membership, status: :approved)
      withdrawal = create(:club_membership, status: :withdrawal_requested)
      expect(ClubMembership.withdrawal_requested).to include(withdrawal)
      expect(ClubMembership.withdrawal_requested).not_to include(approved)
    end
  end
end
