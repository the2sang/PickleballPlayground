require "rails_helper"

RSpec.describe "TournamentTeams", type: :request do
  let(:owner)      { create(:user) }
  let(:other)      { create(:user) }
  let(:club)       { create(:club, owner: owner) }
  let(:tournament) { create(:tournament, club: club) }
  let(:event)      { create(:tournament_event, tournament: tournament) }

  describe "POST /tournament_events/:tournament_event_id/tournament_teams (bulk)" do
    let(:bulk_params) do
      { teams: [ { name: "팀A", seed: 1 }, { name: "팀B", seed: 2 },
                { name: "팀C", seed: "" }, { name: "팀D", seed: "" } ] }
    end

    it "비로그인 시 리다이렉트" do
      post tournament_event_tournament_teams_path(event), params: bulk_params
      expect(response).to redirect_to(new_session_path)
    end

    it "오너가 여러 팀 한번에 등록" do
      sign_in(owner)
      expect {
        post tournament_event_tournament_teams_path(event), params: bulk_params
      }.to change(TournamentTeam, :count).by(4)
    end

    it "이름이 빈 행은 무시" do
      sign_in(owner)
      expect {
        post tournament_event_tournament_teams_path(event),
             params: { teams: [ { name: "팀A", seed: 1 }, { name: "", seed: "" } ] }
      }.to change(TournamentTeam, :count).by(1)
    end

    it "player_names 텍스트 저장" do
      sign_in(owner)
      post tournament_event_tournament_teams_path(event),
           params: { teams: { "0" => { name: "팀A", seed: 1, player_names: "홍길동, 박지성" } } }
      expect(TournamentTeam.last.player_names).to eq("홍길동, 박지성")
    end

    it "player_user_ids로 TournamentTeamMember 생성" do
      sign_in(owner)
      member = create(:user)
      create(:club_membership, club: club, user: member, status: :approved)
      expect {
        post tournament_event_tournament_teams_path(event),
             params: { teams: { "0" => { name: "팀A", seed: "", player_names: "", player_user_ids: [ member.id.to_s ] } } }
      }.to change(TournamentTeamMember, :count).by(1)
    end

    it "타인은 403" do
      sign_in(other)
      post tournament_event_tournament_teams_path(event), params: bulk_params
      expect(response).to redirect_to(root_path)
    end
  end
end
