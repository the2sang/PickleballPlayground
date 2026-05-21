require "rails_helper"

RSpec.describe FlashMeetupPolicy, type: :policy do
  let(:organizer) { create(:user, :profile_complete) }
  let(:other)     { create(:user, :profile_complete) }
  let(:admin)     { create(:user, :admin) }
  let(:meetup)    { create(:flash_meetup, user: organizer) }

  def policy(user) = described_class.new(user, meetup)

  describe "#index? / #show?" do
    it "비로그인 허용" do
      expect(described_class.new(nil, meetup).index?).to be true
      expect(described_class.new(nil, meetup).show?).to be true
    end
  end

  describe "#create?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, FlashMeetup.new).create?).to be false
    end

    it "프로필 미완료 거부" do
      expect(described_class.new(create(:user), FlashMeetup.new).create?).to be false
    end

    it "프로필 완료 허용" do
      expect(described_class.new(other, FlashMeetup.new).create?).to be true
    end
  end

  describe "#update? / #destroy?" do
    it "개설자 허용" do
      expect(policy(organizer).update?).to be true
      expect(policy(organizer).destroy?).to be true
    end

    it "admin 허용" do
      expect(policy(admin).update?).to be true
      expect(policy(admin).destroy?).to be true
    end

    it "타인 거부" do
      expect(policy(other).update?).to be false
      expect(policy(other).destroy?).to be false
    end

    it "비로그인 거부" do
      expect(described_class.new(nil, meetup).destroy?).to be false
    end
  end

  describe "Scope" do
    it "upcoming 모임만 반환" do
      create(:flash_meetup, scheduled_at: 1.day.ago)
      upcoming = create(:flash_meetup, scheduled_at: 1.day.from_now)
      scope = described_class::Scope.new(nil, FlashMeetup).resolve
      expect(scope).to include(upcoming)
    end
  end
end
