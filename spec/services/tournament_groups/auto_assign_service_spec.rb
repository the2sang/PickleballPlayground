require "rails_helper"

RSpec.describe TournamentGroups::AutoAssignService, type: :service do
  subject(:result) { described_class.call(tournament_event: event, group_count: group_count) }

  let(:club)       { create(:club) }
  let(:tournament) { create(:tournament, club: club) }
  let(:event)      { create(:tournament_event, tournament: tournament) }
  let(:group_count) { 2 }

  before do
    4.times { create(:tournament_team, tournament_event: event) }
  end

  describe "성공 케이스" do
    it "성공을 반환한다" do
      expect(result.success?).to be true
    end

    it "요청한 수의 조를 생성한다" do
      result
      expect(event.tournament_groups.count).to eq(2)
    end

    it "조 이름을 A조, B조로 생성한다" do
      result
      expect(event.tournament_groups.pluck(:name)).to match_array(%w[A조 B조])
    end

    it "팀을 조에 균등하게 배분한다" do
      result
      counts = event.tournament_groups.map { |g| g.teams.count }
      expect(counts).to all(be >= 1)
      expect(counts.sum).to eq(4)
    end

    it "각 조의 라운드로빈 경기를 생성한다" do
      result
      event.tournament_groups.each do |group|
        team_count = group.teams.count
        expected_matches = team_count * (team_count - 1) / 2
        expect(group.matches.count).to eq(expected_matches)
      end
    end

    it "TournamentEvent status를 qualifying으로 변경한다" do
      result
      expect(event.reload.status).to eq("qualifying")
    end
  end

  context "팀이 없을 때" do
    before { event.tournament_teams.destroy_all }

    it "실패를 반환한다" do
      expect(result.success?).to be false
    end

    it "에러 메시지를 포함한다" do
      expect(result.error).to be_present
    end
  end
end
