require "rails_helper"

RSpec.describe MatchPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:other)        { create(:user) }
  let(:admin)        { create(:user, :admin) }
  let(:club)         { create(:club, owner: owner) }
  let(:tournament)   { create(:tournament, club: club) }
  let(:event)        { create(:tournament_event, tournament: tournament) }
  let(:group)        { create(:tournament_group, tournament_event: event) }
  let(:team_a)       { create(:tournament_team, tournament_event: event) }
  let(:team_b)       { create(:tournament_team, tournament_event: event) }
  let(:match)        { create(:match, matchable: group, home_team: team_a, away_team: team_b) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end

  def policy(user) = described_class.new(user, match)

  describe "#index? / #show?" do
    it "누구나 허용" do
      expect(described_class.new(nil, match).index?).to be true
      expect(described_class.new(nil, match).show?).to be true
    end
  end

  describe "#update?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, match).update?).to be false
    end

    it "타인 거부" do
      expect(policy(other).update?).to be false
    end

    it "클럽 오너 허용" do
      expect(policy(owner).update?).to be true
    end

    it "클럽 매니저 허용" do
      expect(policy(manager_user).update?).to be true
    end

    it "어드민 허용" do
      expect(policy(admin).update?).to be true
    end

    it "locked 경기는 거부" do
      match.update!(status: :locked)
      expect(policy(owner).update?).to be false
      expect(policy(admin).update?).to be false
    end
  end

  describe "TournamentEvent matchable" do
    let(:bracket_match) { create(:match, matchable: event, home_team: team_a, away_team: team_b) }

    it "본선 경기도 오너 허용" do
      expect(described_class.new(owner, bracket_match).update?).to be true
    end
  end
end
