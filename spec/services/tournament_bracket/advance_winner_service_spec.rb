require "rails_helper"

RSpec.describe TournamentBracket::AdvanceWinnerService, type: :service do
  let(:event)      { create(:tournament_event) }
  let(:home)       { create(:tournament_team, tournament_event: event) }
  let(:away)       { create(:tournament_team, tournament_event: event) }
  let(:final)      { create(:match, matchable: event, match_number: 2, status: :pending) }
  let(:semi)       { create(:match, matchable: event, home_team: home, away_team: away, match_number: 1, next_match: final, status: :completed, winner: home) }

  subject(:result) { described_class.call(match: semi) }

  it "성공을 반환한다" do
    expect(result.success?).to be true
  end

  it "승자를 다음 경기의 home_team 또는 away_team에 배정한다" do
    result
    final.reload
    expect([ final.home_team_id, final.away_team_id ]).to include(home.id)
  end

  it "현재 경기를 locked 상태로 변경한다" do
    result
    expect(semi.reload.status).to eq("locked")
  end

  context "next_match가 없을 때 (결승 우승)" do
    let(:final_match) { create(:match, matchable: event, home_team: home, away_team: away, match_number: 3, status: :completed, winner: home) }

    subject(:result) { described_class.call(match: final_match) }

    it "성공을 반환한다" do
      expect(result.success?).to be true
    end

    it "TournamentEvent를 completed로 변경한다" do
      result
      expect(event.reload.status).to eq("completed")
    end
  end
end
