require "rails_helper"

RSpec.describe TournamentBracket::GenerateService, type: :service do
  subject(:result) { described_class.call(tournament_event: event) }

  let(:club)       { create(:club) }
  let(:tournament) { create(:tournament, club: club) }
  let(:event)      { create(:tournament_event, tournament: tournament, advances_per_group: 1) }

  def create_group_with_winner(name, winner_name)
    group = create(:tournament_group, tournament_event: event, name: name)
    teams = 3.times.map { create(:tournament_team, tournament_event: event) }
    teams.each { |t| create(:tournament_group_team, tournament_group: group, tournament_team: t) }
    winner = create(:tournament_team, tournament_event: event, name: winner_name)
    create(:tournament_group_team, tournament_group: group, tournament_team: winner)
    # 해당 팀이 1위가 되도록 completed 경기 설정
    teams.each do |t|
      m = create(:match, matchable: group, home_team: winner, away_team: t,
                         status: :completed, winner: winner, match_number: Match.count + 1)
      create(:match_set, match: m, set_number: 1, home_score: 11, away_score: 5)
    end
    winner
  end

  context "4개 조 × 1위 진출 = 4팀 브라켓" do
    before do
      create_group_with_winner("A조", "A1")
      create_group_with_winner("B조", "B1")
      create_group_with_winner("C조", "C1")
      create_group_with_winner("D조", "D1")
    end

    it "성공을 반환한다" do
      expect(result.success?).to be true
    end

    it "준결승(2경기) + 결승(1경기) = 3경기를 생성한다" do
      result
      bracket_matches = Match.where(matchable: event)
      expect(bracket_matches.count).to eq(3)
    end

    it "TournamentEvent status를 bracket으로 변경한다" do
      result
      expect(event.reload.status).to eq("bracket")
    end

    it "결승전의 next_match_id는 nil이다" do
      result
      final = Match.where(matchable: event).order(round: :desc).first
      expect(final.next_match_id).to be_nil
    end

    it "준결승 승자가 결승으로 연결된다 (next_match_id 체인)" do
      result
      semis = Match.where(matchable: event, round: 1)
      semis.each do |semi|
        expect(semi.next_match_id).to be_present
      end
    end
  end

  context "2개 조 × 2위 진출 = 4팀 (같은 조 R1 미배정 검증)" do
    let(:event) { create(:tournament_event, tournament: tournament, advances_per_group: 2) }

    def create_group_with_top2(group_name, rank1_name, rank2_name)
      group  = create(:tournament_group, tournament_event: event, name: group_name)
      rank1  = create(:tournament_team, tournament_event: event, name: rank1_name)
      rank2  = create(:tournament_team, tournament_event: event, name: rank2_name)
      loser  = create(:tournament_team, tournament_event: event)
      [ rank1, rank2, loser ].each { |t| create(:tournament_group_team, tournament_group: group, tournament_team: t) }
      m1 = create(:match, matchable: group, home_team: rank1, away_team: loser, status: :completed, winner: rank1, match_number: Match.count + 1)
      create(:match_set, match: m1, set_number: 1, home_score: 11, away_score: 3)
      m2 = create(:match, matchable: group, home_team: rank2, away_team: loser, status: :completed, winner: rank2, match_number: Match.count + 1)
      create(:match_set, match: m2, set_number: 1, home_score: 11, away_score: 6)
      [ rank1, rank2, group ]
    end

    before do
      @a1, @a2, @group_a = create_group_with_top2("A조", "A1", "A2")
      @b1, @b2, @group_b = create_group_with_top2("B조", "B1", "B2")
    end

    it "성공을 반환한다" do
      expect(result.success?).to be true
    end

    it "준결승(2경기) + 결승(1경기) = 3경기를 생성한다" do
      result
      expect(Match.where(matchable: event).count).to eq(3)
    end

    it "1라운드 경기에서 같은 조 팀끼리 대전하지 않는다" do
      result
      a_ids = @group_a.teams.pluck(:id).to_set
      b_ids = @group_b.teams.pluck(:id).to_set
      Match.where(matchable: event, round: 1).each do |m|
        both_in_a = a_ids.include?(m.home_team_id) && a_ids.include?(m.away_team_id)
        both_in_b = b_ids.include?(m.home_team_id) && b_ids.include?(m.away_team_id)
        expect(both_in_a).to be false
        expect(both_in_b).to be false
      end
    end
  end

  context "3개 조 × 1위 = 3팀 → bye 자동 삽입으로 4강 브라켓" do
    before do
      create_group_with_winner("A조", "A1")
      create_group_with_winner("B조", "B1")
      create_group_with_winner("C조", "C1")
    end

    it "성공을 반환한다" do
      expect(result.success?).to be true
    end

    it "bye 경기가 1개 포함된다" do
      result
      bye_match = Match.where(matchable: event).find { |m| m.bye? }
      expect(bye_match).to be_present
    end
  end
end
