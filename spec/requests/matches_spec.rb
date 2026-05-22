require "rails_helper"

RSpec.describe "Matches", type: :request do
  let(:owner)      { create(:user) }
  let(:other)      { create(:user) }
  let(:club)       { create(:club, owner: owner) }
  let(:tournament) { create(:tournament, club: club) }
  let(:event)      { create(:tournament_event, tournament: tournament, points_to_win: 11) }
  let(:group)      { create(:tournament_group, tournament_event: event) }
  let(:team_a)     { create(:tournament_team, tournament_event: event) }
  let(:team_b)     { create(:tournament_team, tournament_event: event) }
  let(:match)      { create(:match, matchable: group, home_team: team_a, away_team: team_b) }

  describe "GET /matches/:id" do
    it "비로그인도 접근 가능" do
      get match_path(match)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /matches/:id" do
    let(:sets_params) { { sets: { "0" => { home_score: "11", away_score: "5" } } } }

    it "비로그인 시 리다이렉트" do
      patch match_path(match), params: sets_params
      expect(response).to redirect_to(new_session_path)
    end

    it "오너가 결과 입력" do
      sign_in(owner)
      patch match_path(match), params: sets_params
      expect(match.reload.status).to eq("completed")
      expect(match.winner).to eq(team_a)
    end

    it "타인은 403" do
      sign_in(other)
      patch match_path(match), params: sets_params
      expect(response).to redirect_to(root_path)
    end

    it "locked 경기는 403" do
      sign_in(owner)
      match.update!(status: :locked)
      patch match_path(match), params: sets_params
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /matches/:id/advance_winner" do
    it "승자를 다음 라운드에 배정 (next_match 있는 경우)" do
      final = create(:match, matchable: event, home_team: nil, away_team: nil)
      semi  = create(:match, matchable: event, home_team: team_a, away_team: team_b,
                             winner: team_a, status: :completed, next_match: final)
      sign_in(owner)
      post advance_winner_match_path(semi)
      expect(semi.reload.status).to eq("locked")
      expect(final.reload.home_team).to eq(team_a)
    end
  end
end
