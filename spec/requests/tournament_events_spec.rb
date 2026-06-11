require "rails_helper"

RSpec.describe "TournamentEvents", type: :request do
  before { host! "localhost" }

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

    it "조별 리그 대진표와 예선 통과팀 선택 UI를 표시한다" do
      group = create(:tournament_group, tournament_event: event, name: "A조")
      team_a = create(:tournament_team, tournament_event: event, name: "A팀", player_names: "김하나")
      team_b = create(:tournament_team, tournament_event: event, name: "B팀", player_names: "박두리")
      create(:tournament_group_team, tournament_group: group, tournament_team: team_a)
      create(:tournament_group_team, tournament_group: group, tournament_team: team_b)
      match = create(:match, matchable: group, home_team: team_a, away_team: team_b,
                             match_number: 1, status: :completed, winner: team_a)
      create(:match_set, match: match, set_number: 1, home_score: 11, away_score: 5)
      event.update!(status: :qualifying)

      sign_in(owner)
      get tournament_event_path(event)

      expect(response.body).to include("조별 리그 대시보드")
      expect(response.body).to include("예선 통과팀 선택")
      expect(response.body).to include(">A팀</span>")
      expect(response.body).to include(">(김하나)</span>")
      expect(response.body).to include(">B팀</span>")
      expect(response.body).to include(">(박두리)</span>")
      expect(response.body).to include("min-width:646px")
      expect(response.body).to include("min-width:133px")
      expect(response.body).to include("background:#eff6ff;color:#2563eb;")
      expect(response.body).to include('data-controller="bracket-selection"')
      expect(response.body).to include("진출 선택")
      expect(response.body).to include("선택팀으로 본선 대진 생성")
      expect(response.body).to include('name="manual_advancing_selection"')
      expect(response.body).not_to include('type="checkbox"')
      expect(response.body).to include("본선 대진표")
      expect(response.body).to include("매칭하기")
    end

    it "참가팀을 팀명과 팀원명 2행 형식으로 표시한다" do
      create(:tournament_team, tournament_event: event, name: "스매시", player_names: "김하나, 박두리")

      get tournament_event_path(event)

      expect(response.body).to include(">스매시</span>")
      expect(response.body).to include(">(김하나, 박두리)</span>")
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

    it "세부 종목(sub_category) 포함 생성" do
      sign_in(owner)
      post tournament_tournament_events_path(tournament),
           params: valid_params.deep_merge(tournament_event: { sub_category: "40+" })
      expect(TournamentEvent.last.sub_category).to eq("40+")
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

  describe "POST /tournament_events/:id/generate_bracket" do
    def create_group_with_top2(group_name, rank1_name, rank2_name)
      group = create(:tournament_group, tournament_event: event, name: group_name)
      rank1 = create(:tournament_team, tournament_event: event, name: rank1_name)
      rank2 = create(:tournament_team, tournament_event: event, name: rank2_name)
      loser = create(:tournament_team, tournament_event: event)
      [ rank1, rank2, loser ].each { |team| create(:tournament_group_team, tournament_group: group, tournament_team: team) }
      m1 = create(:match, matchable: group, home_team: rank1, away_team: loser,
                          status: :completed, winner: rank1, match_number: Match.count + 1)
      create(:match_set, match: m1, set_number: 1, home_score: 11, away_score: 3)
      m2 = create(:match, matchable: group, home_team: rank2, away_team: loser,
                          status: :completed, winner: rank2, match_number: Match.count + 1)
      create(:match_set, match: m2, set_number: 1, home_score: 11, away_score: 6)
    end

    it "오너가 매칭하기로 예선 리그 결과 기반 본선 대진 생성" do
      event.update!(advances_per_group: 2, status: :qualifying)
      create_group_with_top2("A조", "A1", "A2")
      create_group_with_top2("B조", "B1", "B2")

      sign_in(owner)
      post generate_bracket_tournament_event_path(event)

      expect(response).to redirect_to(tournament_event_path(event))
      expect(event.reload.status).to eq("bracket")
      pair_names = Match.where(matchable: event, round: 1).order(:match_number).map do |match|
        [ match.home_team.name, match.away_team.name ]
      end
      expect(pair_names).to eq([ %w[A1 B2], %w[B1 A2] ])
    end

    it "오너가 선택한 예선 통과팀으로 본선 대진 생성" do
      group = create(:tournament_group, tournament_event: event)
      teams = 4.times.map { |i| create(:tournament_team, tournament_event: event, name: "통과#{i + 1}") }
      teams.each { |team| create(:tournament_group_team, tournament_group: group, tournament_team: team) }
      event.update!(status: :qualifying)

      sign_in(owner)
      expect {
        post generate_bracket_tournament_event_path(event),
             params: { manual_advancing_selection: "1", advancing_team_ids: teams.map(&:id) }
      }.to change { Match.where(matchable: event).count }.by(3)

      expect(response).to redirect_to(tournament_event_path(event))
      expect(event.reload.status).to eq("bracket")
    end

    it "수동 선택에서 선택팀 없이 요청하면 종목 화면으로 돌려보낸다" do
      group = create(:tournament_group, tournament_event: event)
      create(:tournament_team, tournament_event: event).tap do |team|
        create(:tournament_group_team, tournament_group: group, tournament_team: team)
      end
      event.update!(status: :qualifying)
      sign_in(owner)

      expect {
        post generate_bracket_tournament_event_path(event), params: { manual_advancing_selection: "1" }
      }.not_to change { Match.where(matchable: event).count }

      expect(response).to redirect_to(tournament_event_path(event))
      expect(flash[:alert]).to be_present
    end
  end
end
