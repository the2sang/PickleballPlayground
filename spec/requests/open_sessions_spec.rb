require "rails_helper"

RSpec.describe "OpenSessions", type: :request do
  let(:manager) { create(:user, :profile_complete) }
  let(:club)    { create(:club, owner: manager) }
  let(:member)  { create(:user, :profile_complete) }

  let(:valid_params) do
    {
      game_session: {
        title: "수요 오픈게임",
        venue_name: "올림픽 체육관",
        scheduled_date: (Date.current + 1).to_s,
        start_time: "19:00",
        end_time: "21:00",
        level: "intermediate",
        court_name: "A코트",
        max_participants: 8,
        visibility: "public_visibility"
      }
    }
  end

  describe "GET /clubs/:club_id/open_sessions" do
    it "비로그인 사용자도 접근 가능하다" do
      get club_open_sessions_path(club)
      expect(response).to have_http_status(:ok)
    end

    it "공개 세션은 보이고 회원전용 세션은 비로그인 사용자에게 숨긴다" do
      public_session  = create(:game_session, :with_court, club: club, title: "공개세션")
      members_session = create(:game_session, :members_only, club: club, title: "회원세션")

      get club_open_sessions_path(club)

      expect(response.body).to include(public_session.title)
      expect(response.body).not_to include(members_session.title)
    end
  end

  describe "POST /clubs/:club_id/open_sessions" do
    context "클럽 관리자" do
      before { sign_in(manager) }

      it "세션을 추가한다" do
        expect {
          post club_open_sessions_path(club), params: valid_params
        }.to change { club.game_sessions.count }.by(1)
        expect(response).to redirect_to(club_open_sessions_path(club))
        expect(club.game_sessions.last.court_name).to eq("A코트")
        expect(club.game_sessions.last.level).to eq("intermediate")
      end

      it "copy_from 으로 마지막 세션을 복사하고 코트명을 비운다" do
        source = create(:game_session, :with_court, club: club,
                        level: :advanced, max_participants: 6, title: "원본세션")

        expect {
          post club_open_sessions_path(club), params: { copy_from: source.id }
        }.to change { club.game_sessions.count }.by(1)

        copy = club.game_sessions.order(:created_at).last
        expect(copy.level).to eq("advanced")
        expect(copy.max_participants).to eq(6)
        expect(copy.court_name).to be_blank
        expect(copy.title).to eq("원본세션")
      end
    end

    context "일반 회원(관리자 아님)" do
      before { sign_in(member) }

      it "권한이 없어 세션을 추가하지 못한다" do
        expect {
          post club_open_sessions_path(club), params: valid_params
        }.not_to change { GameSession.count }
        expect(response).to redirect_to(root_path)
      end
    end

    context "비로그인 사용자" do
      it "세션을 추가하지 못한다" do
        expect {
          post club_open_sessions_path(club), params: valid_params
        }.not_to change { GameSession.count }
      end
    end
  end

  describe "오픈 세션에서 슬롯 신청" do
    let(:session) { create(:game_session, :with_court, club: club) }

    it "회원이 신청하면 오픈 세션 페이지로 돌아온다" do
      sign_in(member)

      expect {
        post game_session_participations_path(session),
             params: { return_to: club_open_sessions_path(club) }
      }.to change { session.participations.confirmed.count }.by(1)

      expect(response).to redirect_to(club_open_sessions_path(club))
    end

    it "외부 URL 로의 return_to 는 무시한다" do
      sign_in(member)

      post game_session_participations_path(session),
           params: { return_to: "https://evil.example.com" }

      expect(response).to redirect_to(game_session_path(session))
    end
  end
end
