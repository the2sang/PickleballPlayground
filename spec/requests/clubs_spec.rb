require "rails_helper"

RSpec.describe "Clubs", type: :request do
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
