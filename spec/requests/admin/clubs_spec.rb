require "rails_helper"

RSpec.describe "Admin clubs", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "PATCH /admin/clubs/:id" do
    it "toggles a club hot zone flag" do
      club = create(:club, status: :approved, hot_zone: false)

      patch admin_club_path(club), params: { club: { hot_zone: "1" } }

      expect(response).to redirect_to(admin_clubs_path)
      expect(club.reload).to be_hot_zone
    end
  end
end
