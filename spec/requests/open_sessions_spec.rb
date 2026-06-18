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
      public_session  = create(:game_session, :open_game, :with_court, club: club, title: "공개세션")
      members_session = create(:game_session, :open_game, :members_only, club: club, title: "회원세션")

      get club_open_sessions_path(club)

      expect(response.body).to include(public_session.title)
      expect(response.body).not_to include(members_session.title)
    end

    it "일반(클럽 운동) 세션은 오픈 게임 페이지에 표시하지 않는다" do
      open_one    = create(:game_session, :open_game, club: club, title: "오픈게임세션")
      regular_one = create(:game_session, club: club, title: "일반운동세션")

      get club_open_sessions_path(club)

      expect(response.body).to include(open_one.title)
      expect(response.body).not_to include(regular_one.title)
    end

    it "open_session_id 로 이동한 세션 카드를 펼친다" do
      session = create(:game_session, :open_game, :with_court, club: club, scheduled_date: Date.current + 1)

      get club_open_sessions_path(club, open_session_id: session.id)

      html = Nokogiri::HTML(response.body)
      card = html.at_css("#open_session_#{session.id}")
      expect(card).to be_present
      expect(card.at_css(".oss-card__header")["aria-expanded"]).to eq("true")
      expect(card.at_css(".oss-card__panel")["hidden"]).to be_nil
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
        expect(club.game_sessions.last).to be_open_game
      end

      it "copy_from 으로 마지막 세션을 복사하고 코트명을 비운다" do
        source = create(:game_session, :open_game, :with_court, club: club,
                        level: :advanced, max_participants: 6, title: "원본세션")

        expect {
          post club_open_sessions_path(club), params: { copy_from: source.id }
        }.to change { club.game_sessions.count }.by(1)

        copy = club.game_sessions.order(:created_at).last
        expect(copy.level).to eq("advanced")
        expect(copy.max_participants).to eq(6)
        expect(copy.court_name).to be_blank
        expect(copy.title).to eq("원본세션")
        expect(copy).to be_open_game
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
    let(:session) { create(:game_session, :open_game, :with_court, club: club) }

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

  describe "신청 UI 노출" do
    let!(:session) { create(:game_session, :open_game, :with_court, club: club) }

    it "프로필 완성 회원에게는 참가 신청 모달이 렌더된다" do
      sign_in(member)
      get club_open_sessions_path(club)
      expect(response.body).to include("참가 신청")
      expect(response.body).to include("data-action=\"click->modal#open\"")
    end

    it "이미 신청한 회원에게는 신청 취소 버튼이 보인다" do
      create(:participation, game_session: session, user: member, status: :confirmed)
      sign_in(member)
      get club_open_sessions_path(club)
      expect(response.body).to include("신청 취소")
    end

    it "비로그인 사용자에게는 로그인 유도 링크가 보인다" do
      get club_open_sessions_path(club)
      expect(response.body).to include(new_session_path(return_to: club_open_sessions_path(club)))
    end

    it "정원이 차기 전에는 대기자 박스 모집 버튼을 비활성화한다" do
      session.update!(max_participants: 2)
      create(:participation, :profile_complete_user, game_session: session, status: :confirmed)
      sign_in(member)

      get club_open_sessions_path(club)

      html = Nokogiri::HTML(response.body)
      wait_slots = html.css(".oss-slot--wait")
      expect(wait_slots).to be_present
      expect(wait_slots.first.at_css(".oss-slot__recruit--disabled[disabled]")).to be_present
      expect(wait_slots.first.at_css("[data-action='click->modal#open']")).to be_nil
    end

    it "정원이 모두 차면 대기자 박스 모집 버튼을 활성화한다" do
      session.update!(max_participants: 2)
      create_list(:participation, 2, :profile_complete_user, game_session: session, status: :confirmed)
      sign_in(member)

      get club_open_sessions_path(club)

      html = Nokogiri::HTML(response.body)
      wait_slots = html.css(".oss-slot--wait")
      expect(wait_slots).to be_present
      expect(wait_slots.first.at_css(".oss-slot__recruit--disabled[disabled]")).to be_nil
      expect(wait_slots.first.at_css(".oss-slot__recruit[data-action='click->modal#open']")).to be_present
    end

    it "슬롯과 신청자 이름 팝업에 참가자 기본 정보를 렌더한다" do
      applicant = create(:user, :profile_complete, :male, :intermediate, :thirties, display_name: "홍길동")
      create(:participation, game_session: session, user: applicant, status: :confirmed)

      get club_open_sessions_path(club)

      expect(response.body.scan("oss-participant-popup-trigger").size).to be >= 2
      expect(response.body).to include("oss-slot__name-text")
      expect(response.body).to include("oss-participant-popup")
      expect(response.body).to include("홍길동")
      expect(response.body).to include("성별")
      expect(response.body).to include("남성")
      expect(response.body).to include("운동레벨")
      expect(response.body).to include("중급")
      expect(response.body).to include("연령대")
      expect(response.body).to include("30대")
    end
  end
end
