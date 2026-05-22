require "rails_helper"

RSpec.describe TournamentTeamPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:other)        { create(:user) }
  let(:admin)        { create(:user, :admin) }
  let(:club)         { create(:club, owner: owner) }
  let(:tournament)   { create(:tournament, club: club) }
  let(:event)        { create(:tournament_event, tournament: tournament) }
  let(:team)         { create(:tournament_team, tournament_event: event) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end

  def policy(user) = described_class.new(user, team)

  describe "#index? / #show?" do
    it "누구나 허용" do
      expect(described_class.new(nil, team).index?).to be true
      expect(described_class.new(nil, team).show?).to be true
    end
  end

  describe "#create? / #update? / #destroy?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, team).create?).to be false
    end

    it "타인 거부" do
      expect(policy(other).create?).to be false
      expect(policy(other).destroy?).to be false
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
      expect(policy(admin).destroy?).to be true
    end
  end
end
