require "rails_helper"

RSpec.describe FlashMeetupParticipation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:flash_meetup) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }

    context "중복 신청 방지" do
      it "동일 모임에 confirmed 상태로 중복 신청 불가" do
        existing = create(:flash_meetup_participation, status: :confirmed)
        duplicate = build(:flash_meetup_participation,
                          flash_meetup: existing.flash_meetup,
                          user: existing.user,
                          status: :confirmed)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:base]).to be_present
      end

      it "cancelled 상태에서는 재신청 가능" do
        cancelled = create(:flash_meetup_participation, :cancelled)
        new_participation = build(:flash_meetup_participation,
                                  flash_meetup: cancelled.flash_meetup,
                                  user: cancelled.user,
                                  status: :confirmed)
        expect(new_participation).to be_valid
      end

      it "다른 모임에는 중복 신청 가능" do
        existing = create(:flash_meetup_participation, status: :confirmed)
        other_meetup = create(:flash_meetup)
        other = build(:flash_meetup_participation,
                      flash_meetup: other_meetup,
                      user: existing.user,
                      status: :confirmed)
        expect(other).to be_valid
      end
    end
  end

  describe "#promote_from_waitlist!" do
    it "waitlisted → confirmed 로 변경" do
      participation = create(:flash_meetup_participation, :waitlisted)
      participation.promote_from_waitlist!
      expect(participation.reload).to be_confirmed
    end
  end
end
