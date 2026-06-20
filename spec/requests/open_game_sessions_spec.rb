require "rails_helper"

RSpec.describe "OpenGameSessions", type: :request do
  before { host! "localhost" }

  let(:manager) { create(:user, :profile_complete) }
  let(:club) { create(:club, owner: manager) }

  describe "GET /open_game_sessions" do
    it "종료 세션은 오렌지 종료 배지, 접수 가능한 세션은 그린 접수중 배지를 표시한다" do
      ended_session = create(:game_session, :open_game, :with_court,
                             club: club,
                             title: "지난 오픈게임",
                             scheduled_date: Date.current - 1,
                             start_time: Time.zone.parse("09:00"),
                             end_time: Time.zone.parse("10:00"))
      create(:game_session, :open_game, :with_court,
             club: club,
             title: "접수 오픈게임",
             scheduled_date: Date.current + 1,
             start_time: Time.zone.parse("19:00"),
             end_time: Time.zone.parse("21:00"),
             status: :open)

      get open_game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("지난 오픈게임")
      expect(response.body).to include("접수 오픈게임")
      expect(response.body).to include("background:#f97316")
      expect(response.body).to include(">종료</span>")
      expect(response.body).to include("background:#16a34a")
      expect(response.body).to include(">접수중</span>")
      expect(response.body).to include(club_open_sessions_path(club, open_session_id: ended_session.id, anchor: "open_session_#{ended_session.id}"))
    end

    it "게임 시작일시가 늦은 오픈 게임을 먼저 보여준다" do
      earlier = create(:game_session, :open_game, :with_court,
                       club: club,
                       title: "오전 오픈게임",
                       scheduled_date: Date.current + 1,
                       start_time: Time.zone.parse("09:00"),
                       end_time: Time.zone.parse("11:00"))
      later = create(:game_session, :open_game, :with_court,
                     club: club,
                     title: "저녁 오픈게임",
                     scheduled_date: Date.current + 1,
                     start_time: Time.zone.parse("19:00"),
                     end_time: Time.zone.parse("21:00"))
      future = create(:game_session, :open_game, :with_court,
                      club: club,
                      title: "내일 이후 오픈게임",
                      scheduled_date: Date.current + 2,
                      start_time: Time.zone.parse("08:00"),
                      end_time: Time.zone.parse("10:00"))

      get open_game_sessions_path

      expect(response.body.index(future.title)).to be < response.body.index(later.title)
      expect(response.body.index(later.title)).to be < response.body.index(earlier.title)
    end
  end
end
