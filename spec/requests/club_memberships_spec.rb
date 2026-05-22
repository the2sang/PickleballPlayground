require "rails_helper"

RSpec.describe "ClubMemberships", type: :request do
  describe "POST /clubs/:club_id/club_memberships" do
    let(:club) { create(:club, status: :approved) }
    let(:user) { create(:user) }

    before { sign_in(user) }

    context "Turbo Stream 요청" do
      let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      it "ClubMembership을 생성한다" do
        expect {
          post club_club_memberships_path(club), headers: turbo_headers
        }.to change(ClubMembership, :count).by(1)
      end

      it "turbo_stream 응답을 반환한다" do
        post club_club_memberships_path(club), headers: turbo_headers
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "환영 메시지를 포함한다" do
        post club_club_memberships_path(club), headers: turbo_headers
        expect(response.body).to include("환영")
      end

      it "폭죽 컨트롤러 마커를 포함한다" do
        post club_club_memberships_path(club), headers: turbo_headers
        expect(response.body).to include("club-join")
      end
    end

    context "HTML 요청" do
      it "클럽 페이지로 리다이렉트한다" do
        post club_club_memberships_path(club)
        expect(response).to redirect_to(club_path(club))
      end
    end
  end
end
