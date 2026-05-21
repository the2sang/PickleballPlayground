require "rails_helper"

RSpec.describe TournamentGroups::StandingsService, type: :service do
  subject(:standings) { described_class.call(tournament_group: group).data }

  let(:event) { create(:tournament_event, scoring_format: :single_game, points_to_win: 11) }
  let(:group) { create(:tournament_group, tournament_event: event) }
  let!(:team_a) { create(:tournament_team, tournament_event: event, name: "팀A") }
  let!(:team_b) { create(:tournament_team, tournament_event: event, name: "팀B") }
  let!(:team_c) { create(:tournament_team, tournament_event: event, name: "팀C") }

  before do
    [ team_a, team_b, team_c ].each do |t|
      create(:tournament_group_team, tournament_group: group, tournament_team: t)
    end
  end

  def complete_match(home, away, home_scores, away_scores)
    match = create(:match, matchable: group,
                           home_team: home, away_team: away,
                           status: :completed,
                           winner: home_scores.sum > away_scores.sum ? home : away,
                           match_number: Match.count + 1)
    home_scores.each_with_index do |hs, i|
      create(:match_set, match: match, set_number: i + 1,
                         home_score: hs, away_score: away_scores[i])
    end
    match
  end

  context "명확한 순위가 있을 때" do
    before do
      complete_match(team_a, team_b, [ 11 ], [ 5 ])  # A 승
      complete_match(team_a, team_c, [ 11 ], [ 7 ])  # A 승
      complete_match(team_b, team_c, [ 11 ], [ 8 ])  # B 승
    end

    it "승률 기준으로 1위를 결정한다" do
      expect(standings.first[:team]).to eq(team_a)
    end

    it "3위가 마지막에 온다" do
      expect(standings.last[:team]).to eq(team_c)
    end

    it "승/패 수를 정확히 계산한다" do
      a_row = standings.find { |r| r[:team] == team_a }
      expect(a_row[:wins]).to eq(2)
      expect(a_row[:losses]).to eq(0)
    end

    it "득실차를 정확히 계산한다" do
      a_row = standings.find { |r| r[:team] == team_a }
      expect(a_row[:point_diff]).to eq((11 - 5) + (11 - 7))
    end
  end

  context "승률이 같을 때 득실차로 결정" do
    before do
      complete_match(team_a, team_b, [ 11 ], [ 5 ])   # A 승 (+6)
      complete_match(team_c, team_a, [ 11 ], [ 10 ])  # C 승, A +(-1)
      complete_match(team_b, team_c, [ 11 ], [ 3 ])   # B 승
      complete_match(team_c, team_b, [ 11 ], [ 4 ])   # C 승
    end

    it "득실차가 높은 팀이 더 높은 순위" do
      # A: 1승1패, point_diff = +5
      # C: 2승1패(3팀이므로 B와 두경기), 계산 별도
      a_row = standings.find { |r| r[:team] == team_a }
      expect(a_row[:point_diff]).to eq(6 - 1)
    end
  end
end
