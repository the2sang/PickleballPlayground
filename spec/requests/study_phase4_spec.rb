require "rails_helper"

RSpec.describe "Study — Phase 4 membership scope", type: :request do
  let(:user)  { create(:user) }
  let(:club)  { create(:club) }
  let(:deck)  { create(:deck, :club, owner: club) }
  let!(:card) { create(:card, deck: deck) }

  describe "GET /study — global queue" do
    context "approved club member" do
      before do
        create(:club_membership, club: club, user: user, status: :approved)
        sign_in(user)
      end

      it "includes club deck cards in global queue" do
        get study_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(card.front)
      end
    end

    context "member after revoked (rejected)" do
      before do
        create(:club_membership, club: club, user: user, status: :rejected)
        sign_in(user)
      end

      it "does NOT include revoked club deck cards" do
        get study_path
        expect(response.body).not_to include(card.front)
      end
    end

    context "user with no club membership" do
      before { sign_in(user) }

      it "does NOT include club deck cards" do
        get study_path
        expect(response.body).not_to include(card.front)
      end
    end
  end
end
