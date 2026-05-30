require "rails_helper"

RSpec.describe DeckPolicy do
  subject(:policy) { described_class.new(actor, deck) }

  let(:admin)        { create(:user, :admin) }
  let(:club)         { create(:club) }
  let(:club_owner)   { club.owner }

  let(:manager_membership) do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end
  let(:manager_user)  { create(:user) }

  let(:member_user)   { create(:user) }
  let(:member_membership) do
    create(:club_membership, club: club, user: member_user, role: :member, status: :approved)
  end

  let(:pending_user)  { create(:user) }
  let(:pending_membership) do
    create(:club_membership, club: club, user: pending_user, role: :member, status: :pending)
  end

  let(:outsider) { create(:user) }

  # ── Official decks ────────────────────────────────────────────────────────

  describe "official deck" do
    let(:deck) { create(:deck, :official) }

    context "site_admin" do
      let(:actor) { admin }
      it { is_expected.to be_show }
      it { is_expected.to be_create }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
      it { is_expected.to be_fork }
    end

    context "authenticated user (non-admin)" do
      let(:actor) { outsider }
      it { is_expected.to     be_show }
      it { is_expected.not_to be_create }
      it { is_expected.not_to be_update }
      it { is_expected.not_to be_destroy }
      it { is_expected.to     be_fork }
    end

    context "unauthenticated (nil user)" do
      let(:actor) { nil }
      it { is_expected.to     be_show }
      it { is_expected.not_to be_create }
      it { is_expected.not_to be_fork }
    end
  end

  # ── Club decks ────────────────────────────────────────────────────────────

  describe "club deck" do
    let(:deck) { create(:deck, :club, owner: club) }

    context "site_admin" do
      let(:actor) { admin }
      it { is_expected.to be_show }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
      it { is_expected.to be_fork }
      it { is_expected.to be_feature }
      it { is_expected.to be_moderate }
    end

    context "club owner (implicitly a manager)" do
      let(:actor) { club_owner }
      before { manager_membership } # ensure club_owner has membership record if needed
      it { is_expected.to be_show }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
      it { is_expected.to be_fork }
      it { is_expected.to be_feature }
      it { is_expected.to be_moderate }
    end

    context "approved manager" do
      let(:actor) { manager_user }
      before { manager_membership }
      it { is_expected.to be_show }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
      it { is_expected.to be_fork }
      it { is_expected.to be_feature }
      it { is_expected.to be_moderate }
    end

    context "approved member" do
      let(:actor) { member_user }
      before { member_membership }
      it { is_expected.to     be_show }
      it { is_expected.to     be_fork }
      it { is_expected.not_to be_update }
      it { is_expected.not_to be_destroy }
      it { is_expected.not_to be_feature }
      it { is_expected.not_to be_moderate }
    end

    context "pending member" do
      let(:actor) { pending_user }
      before { pending_membership }
      it { is_expected.not_to be_show }
      it { is_expected.not_to be_fork }
      it { is_expected.not_to be_update }
    end

    context "outsider (authenticated, not a member)" do
      let(:actor) { outsider }
      it { is_expected.not_to be_show }
      it { is_expected.not_to be_fork }
      it { is_expected.not_to be_update }
    end

    context "unauthenticated" do
      let(:actor) { nil }
      it { is_expected.not_to be_show }
      it { is_expected.not_to be_fork }
    end
  end

  # ── Club deck creation (new?) ─────────────────────────────────────────────

  describe "creating a club-scoped deck (new deck record)" do
    let(:new_club_deck) { build(:deck, :club, owner: club) }
    let(:deck) { new_club_deck }

    context "approved member" do
      let(:actor) { member_user }
      before { member_membership }
      it { is_expected.to be_create }
    end

    context "pending member" do
      let(:actor) { pending_user }
      before { pending_membership }
      it { is_expected.not_to be_create }
    end

    context "outsider" do
      let(:actor) { outsider }
      it { is_expected.not_to be_create }
    end
  end

  # ── Personal decks ────────────────────────────────────────────────────────

  describe "personal deck" do
    let(:owner) { create(:user) }
    let(:deck)  { create(:deck, :personal, owner: owner) }

    context "owner" do
      let(:actor) { owner }
      it { is_expected.to be_show }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
      it { is_expected.not_to be_fork }
    end

    context "other authenticated user" do
      let(:actor) { outsider }
      it { is_expected.not_to be_show }
      it { is_expected.not_to be_update }
      it { is_expected.not_to be_destroy }
    end

    context "site_admin" do
      let(:actor) { admin }
      it { is_expected.to be_show }
      it { is_expected.to be_update }
      it { is_expected.to be_destroy }
    end

    context "unauthenticated" do
      let(:actor) { nil }
      it { is_expected.not_to be_show }
    end
  end

  # ── Scope ─────────────────────────────────────────────────────────────────

  describe "Scope" do
    let!(:official_deck) { create(:deck, :official) }
    let!(:club_deck)     { create(:deck, :club, owner: club) }
    let!(:my_deck)       { create(:deck, :personal, owner: member_user) }
    let!(:other_deck)    { create(:deck, :personal, owner: outsider) }

    def resolved(actor)
      described_class::Scope.new(actor, Deck.all).resolve
    end

    context "site_admin" do
      it "sees all decks" do
        expect(resolved(admin)).to include(official_deck, club_deck, my_deck, other_deck)
      end
    end

    context "approved club member" do
      before { member_membership }

      it "sees official, club, own personal — not others' personal" do
        result = resolved(member_user)
        expect(result).to include(official_deck, club_deck, my_deck)
        expect(result).not_to include(other_deck)
      end
    end

    context "outsider (authenticated, no club memberships)" do
      it "sees official and own personal only" do
        result = resolved(outsider)
        expect(result).to include(official_deck)
        expect(result).not_to include(club_deck, my_deck)
        expect(result).to include(other_deck)
      end
    end

    context "unauthenticated" do
      it "sees official decks only" do
        result = resolved(nil)
        expect(result).to include(official_deck)
        expect(result).not_to include(club_deck, my_deck, other_deck)
      end
    end
  end
end
