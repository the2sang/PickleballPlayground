require "rails_helper"

RSpec.describe "CardReviews — Phase 4 auth guards", type: :request do
  let(:user)   { create(:user) }
  let(:club)   { create(:club) }
  let(:deck)   { create(:deck, :club, owner: club) }
  let(:card)   { create(:card, deck: deck) }

  def post_review(rating: 4)
    post card_reviews_path, params: {
      card_review: { card_id: card.id, rating: rating }
    }
  end

  describe "Pitfall 8: POST /card_reviews after club membership revoked" do
    context "approved member" do
      before do
        create(:club_membership, club: club, user: user, status: :approved)
        sign_in(user)
      end

      it "allows review submission" do
        post_review
        expect(response).not_to redirect_to(root_path)
      end
    end

    context "revoked (rejected) member" do
      before do
        create(:club_membership, club: club, user: user, status: :rejected)
        sign_in(user)
      end

      it "redirects with access denied" do
        post_review
        expect(response).to have_http_status(:found)
        expect(flash[:alert]).to be_present
      end
    end

    context "user with no membership" do
      before { sign_in(user) }

      it "redirects with access denied" do
        post_review
        expect(flash[:alert]).to be_present
      end
    end
  end
end
