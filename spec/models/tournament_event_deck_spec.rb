require "rails_helper"

RSpec.describe TournamentEventDeck, type: :model do
  let(:tournament_event) { create(:tournament_event) }
  let(:deck) { Deck.create!(scope: :official, owner: nil, title: "공식 덱 #{SecureRandom.hex(3)}") }

  describe "associations" do
    it { is_expected.to belong_to(:tournament_event) }
    it { is_expected.to belong_to(:deck) }
  end

  describe "validations" do
    subject do
      TournamentEventDeck.new(tournament_event: tournament_event, deck: deck, position: 1)
    end

    it { is_expected.to validate_uniqueness_of(:deck_id).scoped_to(:tournament_event_id) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "TournamentEvent inverse association" do
    it "exposes has_many :tournament_event_decks on TournamentEvent" do
      ted = TournamentEventDeck.create!(tournament_event: tournament_event, deck: deck, position: 1)
      expect(tournament_event.tournament_event_decks).to include(ted)
    end

    it "exposes has_many :decks through tournament_event_decks" do
      TournamentEventDeck.create!(tournament_event: tournament_event, deck: deck, position: 1)
      expect(tournament_event.decks).to include(deck)
    end
  end
end
