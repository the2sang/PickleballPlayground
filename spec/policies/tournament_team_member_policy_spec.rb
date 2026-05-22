require "rails_helper"

RSpec.describe TournamentTeamMemberPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:other)        { create(:user) }
  let(:admin)        { create(:user, :admin) }
  let(:club)         { create(:club, owner: owner) }
  let(:tournament)   { create(:tournament, club: club) }
  let(:event)        { create(:tournament_event, tournament: tournament) }
  let(:team)         { create(:tournament_team, tournament_event: event) }
  let(:member_record) { create(:tournament_team_member, tournament_team: team) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end

  def policy(user) = described_class.new(user, member_record)

  describe "#create? / #destroy?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, member_record).create?).to be false
    end

    it "타인 거부" do
      expect(policy(other).create?).to be false
      expect(policy(other).destroy?).to be false
    end

    it "클럽 오너 허용" do
      expect(policy(owner).create?).to be true
      expect(policy(owner).destroy?).to be true
    end

    it "클럽 매니저 허용" do
      expect(policy(manager_user).create?).to be true
      expect(policy(manager_user).destroy?).to be true
    end

    it "어드민 허용" do
      expect(policy(admin).create?).to be true
      expect(policy(admin).destroy?).to be true
    end
  end
end
