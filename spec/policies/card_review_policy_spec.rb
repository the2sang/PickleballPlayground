require "rails_helper"

RSpec.describe CardReviewPolicy do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:club)       { create(:club) }

  let(:own_review_on_personal) do
    deck = create(:deck, :personal, owner: user)
    card = create(:card, deck: deck)
    create(:card_review, user: user, card: card)
  end

  let(:other_review_on_personal) do
    deck = create(:deck, :personal, owner: user)
    card = create(:card, deck: deck)
    create(:card_review, user: other_user, card: card)
  end

  let(:own_review_on_official) do
    card = create(:card, deck: create(:deck, :official))
    create(:card_review, user: user, card: card)
  end

  # ── user owns the review AND can see the deck ───────────────────────────

  describe "own review on own personal deck" do
    subject(:policy) { described_class.new(user, own_review_on_personal) }

    it { is_expected.to be_create }
    it { is_expected.to be_show }
    it { is_expected.to be_update }
    it { is_expected.to be_destroy }
  end

  describe "own review on official deck (always visible)" do
    subject(:policy) { described_class.new(user, own_review_on_official) }

    it { is_expected.to be_create }
  end

  # ── Pitfall 8: user owns review but lost deck access ────────────────────

  describe "Pitfall 8: own review on club deck after membership revoked" do
    let(:club_deck)  { create(:deck, :club, owner: club) }
    let(:club_card)  { create(:card, deck: club_deck) }
    let(:own_review) { create(:card_review, user: user, card: club_card) }

    context "when user has approved membership" do
      before { create(:club_membership, club: club, user: user, status: :approved) }

      subject(:policy) { described_class.new(user, own_review) }
      it { is_expected.to be_create }
    end

    context "when user membership has been revoked (rejected)" do
      before { create(:club_membership, club: club, user: user, status: :rejected) }

      subject(:policy) { described_class.new(user, own_review) }
      it { is_expected.not_to be_create }
    end

    context "when user has no membership at all" do
      subject(:policy) { described_class.new(user, own_review) }
      it { is_expected.not_to be_create }
    end
  end

  # ── other user's review ─────────────────────────────────────────────────

  describe "review belonging to another user" do
    subject(:policy) { described_class.new(user, other_review_on_personal) }

    it { is_expected.not_to be_create }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_destroy }
  end

  # ── nil user ─────────────────────────────────────────────────────────────

  describe "nil user" do
    subject(:policy) { described_class.new(nil, own_review_on_personal) }

    it { is_expected.not_to be_create }
    it { is_expected.not_to be_show }
  end

  # ── Scope ────────────────────────────────────────────────────────────────

  describe "Scope" do
    it "shows only current user's reviews" do
      r1 = own_review_on_personal
      _r2 = other_review_on_personal

      resolved = described_class::Scope.new(user, CardReview.all).resolve
      expect(resolved.to_a).to eq([ r1 ])
    end

    it "returns empty for nil user" do
      own_review_on_personal
      resolved = described_class::Scope.new(nil, CardReview.all).resolve
      expect(resolved).to be_empty
    end
  end
end
