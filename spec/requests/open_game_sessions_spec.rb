require "rails_helper"

RSpec.describe "OpenGameSessions", type: :request do
  let(:manager) { create(:user, :profile_complete) }
  let(:club) { create(:club, owner: manager) }

  describe "GET /open_game_sessions" do
    it "종료 세션은 오렌지 종료 배지, 접수 가능한 세션은 그린 접수중 배지를 표시한다" do
      create(:game_session, :open_game, :with_court,
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
    end
  end
end
