require "rails_helper"

RSpec.describe ClubNotice, type: :model do
  it "requires a title and body" do
    notice = build(:club_notice, title: "", body: "")

    expect(notice).not_to be_valid
    expect(notice.errors[:title]).to be_present
    expect(notice.errors[:body]).to be_present
  end

  it "orders recent notices first" do
    club = create(:club)
    older = create(:club_notice, club: club, created_at: 2.days.ago)
    newer = create(:club_notice, club: club, created_at: 1.hour.ago)

    expect(club.club_notices.recent).to eq([ newer, older ])
  end
end
