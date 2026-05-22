require "rails_helper"

RSpec.describe Matches::RecordResultService, type: :service do
  let(:event)    { create(:tournament_event, scoring_format: :single_game, points_to_win: 11) }
  let(:group)    { create(:tournament_group, tournament_event: event) }
  let(:home)     { create(:tournament_team, tournament_event: event) }
  let(:away)     { create(:tournament_team, tournament_event: event) }
  let(:match)    { create(:match, matchable: group, home_team: home, away_team: away, match_number: 1) }

  subject(:result) do
    described_class.call(
      match: match,
      sets: sets
    )
  end

  context "단판 11점 정상 승리 (11-8)" do
    let(:sets) { [ { home_score: 11, away_score: 8 } ] }

    it "성공을 반환한다" do
      expect(result.success?).to be true
    end

    it "MatchSet을 저장한다" do
      result
      expect(match.match_sets.count).to eq(1)
    end

    it "홈팀을 승자로 기록한다" do
      result
      expect(match.reload.winner).to eq(home)
    end

    it "match status를 completed로 변경한다" do
      result
      expect(match.reload.status).to eq("completed")
    end
  end

  context "win-by-2 규칙 위반 (10-10)" do
    let(:sets) { [ { home_score: 10, away_score: 10 } ] }

    it "실패를 반환한다" do
      expect(result.success?).to be false
    end

    it "win-by-2 에러 메시지를 포함한다" do
      expect(result.error).to include("2점")
    end
  end

  context "11점 동점에서 연장 유효 점수 (12-10)" do
    let(:sets) { [ { home_score: 12, away_score: 10 } ] }

    it "성공을 반환한다" do
      expect(result.success?).to be true
    end
  end

  context "Best of 3 경기" do
    let(:event) { create(:tournament_event, scoring_format: :best_of_3, points_to_win: 11) }
    let(:sets)  { [ { home_score: 11, away_score: 5 }, { home_score: 8, away_score: 11 }, { home_score: 11, away_score: 9 } ] }

    it "3세트 결과를 저장한다" do
      result
      expect(match.match_sets.count).to eq(3)
    end

    it "2세트 더 많이 이긴 팀을 승자로 기록한다" do
      result
      expect(match.reload.winner).to eq(home)
    end
  end

  context "다음 라운드 경기가 진행 중일 때" do
    let(:sets) { [ { home_score: 11, away_score: 5 } ] }
    let(:next_match) { create(:match, matchable: group, match_number: 2, status: :in_progress) }

    before { match.update!(next_match: next_match) }

    it "성공하지만 경고를 포함한다" do
      expect(result.success?).to be true
      expect(result.warning).to be_present
    end
  end
end
