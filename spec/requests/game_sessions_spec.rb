require "rails_helper"

RSpec.describe "GameSessions", type: :request do
  let(:manager) { create(:user, :profile_complete) }
  let(:club)    { create(:club, owner: manager) }

  describe "POST /game_sessions" do
    let(:params) do
      {
        club_id: club.id,
        game_session: {
          title: "수요 오픈게임",
          venue_name: "올림픽 체육관",
          scheduled_date: (Date.current + 1).to_s,
          start_time: "19:00",
          end_time: "21:00",
          level: "intermediate",
          court_name: "A코트",
          max_participants: 8
        }
      }
    end

    it "관리자가 레벨과 코트명을 지정해 세션을 생성한다" do
      sign_in(manager)

      expect {
        post game_sessions_path, params: params
      }.to change { club.game_sessions.count }.by(1)

      session = club.game_sessions.last
      expect(session.level).to eq("intermediate")
      expect(session.court_name).to eq("A코트")
      expect(session.max_participants).to eq(8)
    end

    it "기본 세션 타입은 regular(클럽 운동 세션) 이다" do
      sign_in(manager)
      post game_sessions_path, params: params
      expect(club.game_sessions.last).to be_regular
    end

    it "session_type=open_game 으로 오픈 게임 세션을 생성한다" do
      sign_in(manager)
      post game_sessions_path, params: params.deep_merge(game_session: { session_type: "open_game" })
      expect(club.game_sessions.last).to be_open_game
    end
  end

  describe "GET /game_sessions/new?session_type=open_game" do
    it "오픈 게임 세션 폼을 미리 채운다" do
      sign_in(manager)
      get new_game_session_path(club_id: club.id, session_type: "open_game")
      expect(response.body).to include('value="open_game"')
    end
  end

  describe "GET /game_sessions/:id" do
    it "오픈 게임 세션 상세에 접수 페이지 이동 버튼을 표시한다" do
      session = create(:game_session, :open_game, :with_court, club: club)
      create(:participation, game_session: session, user: manager, status: :confirmed)
      sign_in(manager)

      get game_session_path(session)

      expect(response.body).to include("접수 페이지로")
      expect(response.body).to include("open_session_id=#{session.id}")
      expect(response.body).to include("#open_session_#{session.id}")
    end
  end
end
