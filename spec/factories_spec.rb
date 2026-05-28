require "rails_helper"

RSpec.describe "FactoryBot factories" do
  # Phase-1 factories only — restrict lint scope to avoid blocking on any
  # pre-existing project factory that may not lint cleanly. This guarantees
  # the Phase-1 polymorphic deck factory + every trait builds and saves.
  PHASE1_FACTORY_NAMES = %i[deck card card_review tournament_event_deck].freeze

  it "builds and saves every Phase-1 factory with every trait" do
    phase1_factories = FactoryBot.factories.select { |f| PHASE1_FACTORY_NAMES.include?(f.name) }
    expect(phase1_factories.map(&:name)).to match_array(PHASE1_FACTORY_NAMES)

    expect { FactoryBot.lint(phase1_factories, traits: true) }.not_to raise_error
  end

  describe "deck factory traits sanity" do
    it "default builds a valid personal Deck owned by a fresh User" do
      deck = build(:deck)
      expect(deck.scope).to eq("personal")
      expect(deck.owner).to be_a(User)
      expect(deck).to be_valid
    end

    it ":official trait yields owner: nil and scope: :official" do
      deck = build(:deck, :official)
      expect(deck.scope).to eq("official")
      expect(deck.owner).to be_nil
      expect(deck).to be_valid
    end

    it ":club trait yields a Club owner" do
      deck = build(:deck, :club)
      expect(deck.scope).to eq("club")
      expect(deck.owner).to be_a(Club)
      expect(deck).to be_valid
    end

    it ":forked trait sets forked_from to a fresh official deck" do
      deck = build(:deck, :personal, :forked)
      expect(deck.forked_from).to be_a(Deck)
      expect(deck.forked_from.official?).to be true
    end

    it ":featured trait sets featured_at" do
      deck = build(:deck, :featured)
      expect(deck.featured_at).to be_present
    end
  end

  describe "card_review factory traits" do
    it ":due trait has next_review_at in the past" do
      cr = build(:card_review, :due)
      expect(cr.next_review_at).to be < Time.current
    end

    it ":mature trait has interval_days=21 and repetitions=5" do
      cr = build(:card_review, :mature)
      expect(cr.interval_days).to eq(21)
      expect(cr.repetitions).to eq(5)
    end
  end

  describe "tournament_event_deck factory" do
    it "builds a valid TournamentEventDeck with an official deck" do
      ted = build(:tournament_event_deck)
      expect(ted.deck.scope).to eq("official")
      expect(ted).to be_valid
    end
  end
end
