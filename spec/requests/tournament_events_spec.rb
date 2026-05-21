require "rails_helper"

RSpec.describe "TournamentEvents", type: :request do
  let(:owner)      { create(:user) }
  let(:other)      { create(:user) }
  let(:club)       { create(:club, owner: owner) }
  let(:tournament) { create(:tournament, club: club) }
  let(:event)      { create(:tournament_event, tournament: tournament) }

  let(:valid_params) do
    { tournament_event: { discipline: "mens_singles", scoring_format: "single_game",
                          points_to_win: 11, advances_per_group: 2 } }
  end

  describe "GET /tournament_events/:id" do
    it "비로그인도 접근 가능" do
      get tournament_event_path(event)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tournaments/:tournament_id/tournament_events" do
    it "비로그인 시 리다이렉트" do
      post tournament_tournament_events_path(tournament), params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "오너가 종목 생성" do
      sign_in(owner)
      expect {
        post tournament_tournament_events_path(tournament), params: valid_params
      }.to change(TournamentEvent, :count).by(1)
    end

    it "타인은 403" do
      sign_in(other)
      post tournament_tournament_events_path(tournament), params: valid_params
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /tournament_events/:id" do
    it "오너가 종목 삭제" do
      sign_in(owner)
      e = create(:tournament_event, tournament: tournament)
      expect {
        delete tournament_event_path(e)
      }.to change(TournamentEvent, :count).by(-1)
    end
  end
end
