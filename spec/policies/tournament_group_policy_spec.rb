require "rails_helper"

RSpec.describe TournamentGroupPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:other)        { create(:user) }
  let(:admin)        { create(:user, :admin) }
  let(:club)         { create(:club, owner: owner) }
  let(:tournament)   { create(:tournament, club: club) }
  let(:event)        { create(:tournament_event, tournament: tournament) }
  let(:group)        { create(:tournament_group, tournament_event: event) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end

  def policy(user) = described_class.new(user, group)

  describe "#index? / #show?" do
    it "누구나 허용" do
      expect(described_class.new(nil, group).index?).to be true
      expect(described_class.new(nil, group).show?).to be true
    end
  end

  describe "#create? / #update? / #destroy?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, group).create?).to be false
    end

    it "타인 거부" do
      expect(policy(other).create?).to be false
    end

    it "클럽 오너 허용" do
      expect(policy(owner).create?).to be true
      expect(policy(owner).update?).to be true
      expect(policy(owner).destroy?).to be true
    end

    it "클럽 매니저 허용" do
      expect(policy(manager_user).create?).to be true
    end

    it "어드민 허용" do
      expect(policy(admin).create?).to be true
    end
  end
end
