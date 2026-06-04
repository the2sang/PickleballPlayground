require "rails_helper"

RSpec.describe FlashMeetupParticipationPolicy, type: :policy do
  let(:user)          { create(:user, :profile_complete) }
  let(:admin)         { create(:user, :admin) }
  let(:meetup)        { create(:flash_meetup) }
  let(:participation) { create(:flash_meetup_participation, flash_meetup: meetup, user: user) }

  describe "#create?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, FlashMeetupParticipation.new).create?).to be false
    end

    it "프로필 미완료 거부" do
      expect(described_class.new(create(:user), FlashMeetupParticipation.new).create?).to be false
    end

    it "프로필 완료 허용" do
      expect(described_class.new(user, FlashMeetupParticipation.new).create?).to be true
    end
  end

  describe "#destroy?" do
    it "본인 취소 허용" do
      expect(described_class.new(user, participation).destroy?).to be true
    end

    it "admin 취소 허용" do
      expect(described_class.new(admin, participation).destroy?).to be true
    end

    it "타인 거부" do
      other = create(:user, :profile_complete)
      expect(described_class.new(other, participation).destroy?).to be false
    end

    it "이미 cancelled 상태는 거부" do
      cancelled = create(:flash_meetup_participation, :cancelled, user: user)
      expect(described_class.new(user, cancelled).destroy?).to be false
    end
  end
end
