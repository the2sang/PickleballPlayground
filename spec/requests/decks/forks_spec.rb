require "rails_helper"

RSpec.describe "Decks::Forks", type: :request do
  let(:user)  { create(:user) }
  let(:club)  { create(:club) }

  let(:official_deck) { create(:deck, :official, title: "공식 덱") }
  let(:club_deck)     { create(:deck, :club, owner: club, title: "클럽 덱") }
  let(:personal_deck) { create(:deck, :personal, title: "개인 덱") }

  describe "POST /decks/:deck_id/fork" do
    context "official deck — authenticated user" do
      before { sign_in(user) }

      it "creates a personal fork and redirects to the new deck" do
        post deck_fork_path(official_deck)

        expect(response).to redirect_to(deck_path(Deck.last))
        forked = Deck.last
        expect(forked.personal?).to be true
        expect(forked.owner).to eq(user)
        expect(forked.forked_from_deck_id).to eq(official_deck.id)
        expect(forked.cards.count).to eq(official_deck.cards.count)
        expect(CardReview.where(card: forked.cards).count).to eq(0)
      end
    end

    context "club deck — approved member" do
      before do
        create(:club_membership, club: club, user: user, status: :approved)
        sign_in(user)
      end

      it "creates a personal fork" do
        create(:card, deck: club_deck)
        post deck_fork_path(club_deck)

        expect(response).to redirect_to(deck_path(Deck.last))
        expect(Deck.last.personal?).to be true
      end
    end

    context "club deck — non-member" do
      before { sign_in(user) }

      it "returns 403 forbidden" do
        post deck_fork_path(club_deck)
        expect(response).to have_http_status(:found) # redirects (Pundit rescue)
        expect(flash[:alert]).to be_present
      end
    end

    context "personal deck — cannot be forked" do
      before { sign_in(user) }

      it "returns 403 forbidden" do
        post deck_fork_path(personal_deck)
        expect(response).to have_http_status(:found)
        expect(flash[:alert]).to be_present
      end
    end

    context "forged forked_from_deck_id parameter" do
      let(:victim_deck) { create(:deck, :official) }
      before { sign_in(user) }

      it "ignores the parameter and forks the route-identified deck" do
        post deck_fork_path(official_deck), params: { forked_from_deck_id: victim_deck.id }
        forked = Deck.last
        expect(forked.forked_from_deck_id).to eq(official_deck.id)
      end
    end

    context "unauthenticated" do
      it "redirects to login" do
        post deck_fork_path(official_deck)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
