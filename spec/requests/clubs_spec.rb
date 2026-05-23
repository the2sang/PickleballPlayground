require "rails_helper"

RSpec.describe "Clubs", type: :request do
  describe "GET /clubs/:id (클럽 상세)" do
    let(:club) { create(:club, status: :approved) }

    it "대회 섹션을 표시한다" do
      get club_path(club)
      expect(response.body).to include("대회")
    end

    it "비로그인 사용자에게 codedash 접속 버튼을 표시하지 않는다" do
      get club_path(club)
      expect(response.body).not_to include("codedash")
      expect(response.body).not_to include("code_dash_session")
    end

    it "클럽의 대회 목록을 표시한다" do
      tournament = create(:tournament, club: club, name: "봄 대회")
      get club_path(club)
      expect(response.body).to include("봄 대회")
    end

    context "클럽 매니저" do
      let(:manager) { create(:user) }
      before do
        create(:club_membership, club: club, user: manager, role: :manager, status: :approved)
        sign_in(manager)
      end

      it "새 대회 만들기 버튼을 표시한다" do
        get club_path(club)
        expect(response.body).to include(new_club_tournament_path(club))
      end
    end

    context "일반 사용자" do
      let(:user) { create(:user) }
      before { sign_in(user) }

      it "새 대회 만들기 버튼을 표시하지 않는다" do
        get club_path(club)
        expect(response.body).not_to include(new_club_tournament_path(club))
      end
    end
  end

  describe "GET /clubs" do
    let!(:approved_club)  { create(:club, status: :approved) }
    let!(:pending_club)   { create(:club, status: :pending) }
    let!(:suspended_club) { create(:club, status: :suspended) }

    context "비로그인 사용자" do
      it "승인된 클럽만 표시한다" do
        get clubs_path
        expect(response.body).to include(approved_club.name)
        expect(response.body).not_to include(pending_club.name)
        expect(response.body).not_to include(suspended_club.name)
      end
    end

    context "일반 사용자" do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it "승인된 클럽만 표시한다" do
        get clubs_path
        expect(response.body).to include(approved_club.name)
        expect(response.body).not_to include(pending_club.name)
        expect(response.body).not_to include(suspended_club.name)
      end
    end

    context "관리자" do
      let(:admin) { create(:user, :admin) }

      before { sign_in(admin) }

      it "공개 클럽 목록에서는 승인된 클럽만 표시한다" do
        get clubs_path
        expect(response.body).to include(approved_club.name)
        expect(response.body).not_to include(pending_club.name)
        expect(response.body).not_to include(suspended_club.name)
      end
    end
  end
end
