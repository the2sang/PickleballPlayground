require "rails_helper"

RSpec.describe "Decks::Features", type: :request do
  let(:club)         { create(:club) }
  let(:club_owner)   { club.owner }
  let(:manager_user) { create(:user) }
  let(:member_user)  { create(:user) }
  let(:outsider)     { create(:user) }
  let(:admin)        { create(:user, :admin) }

  let(:club_deck) { create(:deck, :club, owner: club) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
    create(:club_membership, club: club, user: member_user,  role: :member,  status: :approved)
  end

  describe "POST /decks/:deck_id/feature (feature a deck)" do
    context "club manager" do
      before { sign_in(manager_user) }

      it "sets featured_at and redirects" do
        post deck_feature_path(club_deck)
        expect(response).to have_http_status(:found)
        expect(club_deck.reload.featured_at).not_to be_nil
      end
    end

    context "club owner" do
      before { sign_in(club_owner) }

      it "sets featured_at" do
        post deck_feature_path(club_deck)
        expect(club_deck.reload.featured_at).not_to be_nil
      end
    end

    context "site_admin" do
      before { sign_in(admin) }

      it "sets featured_at" do
        post deck_feature_path(club_deck)
        expect(club_deck.reload.featured_at).not_to be_nil
      end
    end

    context "regular member (no feature permission)" do
      before { sign_in(member_user) }

      it "is redirected with alert" do
        post deck_feature_path(club_deck)
        expect(response).to have_http_status(:found)
        expect(flash[:alert]).to be_present
        expect(club_deck.reload.featured_at).to be_nil
      end
    end

    context "outsider" do
      before { sign_in(outsider) }

      it "is redirected with alert" do
        post deck_feature_path(club_deck)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /decks/:deck_id/feature (unfeature)" do
    let(:featured_deck) { create(:deck, :club, :featured, owner: club) }

    context "club manager" do
      before { sign_in(manager_user) }

      it "clears featured_at" do
        delete deck_feature_path(featured_deck)
        expect(response).to have_http_status(:found)
        expect(featured_deck.reload.featured_at).to be_nil
      end
    end

    context "regular member" do
      before { sign_in(member_user) }

      it "is redirected with alert" do
        delete deck_feature_path(featured_deck)
        expect(flash[:alert]).to be_present
        expect(featured_deck.reload.featured_at).not_to be_nil
      end
    end
  end
end
