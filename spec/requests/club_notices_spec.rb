require "rails_helper"

RSpec.describe "ClubNotices", type: :request do
  let(:club) { create(:club, status: :approved) }
  let(:manager) { create(:user) }

  before do
    create(:club_membership, club: club, user: manager, role: :manager, status: :approved)
  end

  describe "GET /clubs/:club_id/club_notices/new" do
    it "renders the new notice form for a club manager" do
      sign_in(manager)

      get new_club_club_notice_path(club)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("공지사항 등록")
      expect(response.body).to include("제목")
    end
  end

  describe "POST /clubs/:club_id/club_notices" do
    it "creates a notice for a club manager" do
      sign_in(manager)

      expect {
        post club_club_notices_path(club), params: {
          club_notice: {
            title: "대관 변경 안내",
            body: "이번 주 운동 장소가 변경됩니다.",
            published_at: "2026-05-27 10:00"
          }
        }
      }.to change { club.club_notices.count }.by(1)

      notice = club.club_notices.last
      expect(notice.title).to eq("대관 변경 안내")
      expect(response).to redirect_to(manage_club_path(club, anchor: "club-notices"))
    end
  end

  describe "PATCH /clubs/:club_id/club_notices/:id" do
    it "updates a notice for a club manager" do
      sign_in(manager)
      notice = create(:club_notice, club: club, title: "기존 제목")

      patch club_club_notice_path(club, notice), params: {
        club_notice: { title: "수정 제목", body: notice.body }
      }

      expect(response).to redirect_to(manage_club_path(club, anchor: "club-notices"))
      expect(notice.reload.title).to eq("수정 제목")
    end
  end

  describe "DELETE /clubs/:club_id/club_notices/:id" do
    it "deletes a notice for a club manager" do
      sign_in(manager)
      notice = create(:club_notice, club: club)

      expect {
        delete club_club_notice_path(club, notice)
      }.to change { club.club_notices.count }.by(-1)

      expect(response).to redirect_to(manage_club_path(club, anchor: "club-notices"))
    end

    it "does not allow a regular user to delete notices" do
      sign_in(create(:user))
      notice = create(:club_notice, club: club)

      expect {
        delete club_club_notice_path(club, notice)
      }.not_to change { club.club_notices.count }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /clubs/:id/manage" do
    it "shows the notice management list below session management" do
      sign_in(manager)
      create(:club_notice, club: club, title: "운동 공지")

      get manage_club_path(club)

      expect(response.body).to include("운동 세션 관리")
      expect(response.body).to include("공지사항 관리")
      expect(response.body).to include("운동 공지")
      expect(response.body).to include(new_club_club_notice_path(club))
    end
  end

  describe "GET /game_sessions/:id" do
    it "renders the notice modal launcher and recent notice contents" do
      game_session = GameSession.create!(
        club: club,
        title: "토요 정기 운동",
        venue_name: "센터 코트",
        scheduled_date: Date.current + 1.day,
        start_time: "10:00",
        end_time: "12:00",
        court_count: 2,
        fee: 0,
        status: :open
      )
      create(:club_notice, club: club, title: "첫 번째 공지", body: "준비물을 확인해주세요.")

      get game_session_path(game_session)

      expect(response.body).to include("공지사항")
      expect(response.body).to include("첫 번째 공지")
      expect(response.body).to include("준비물을 확인해주세요.")
      expect(response.body).to include("data-controller=\"notice-carousel\"")
    end
  end
end
