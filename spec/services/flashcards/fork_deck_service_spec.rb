require "rails_helper"

RSpec.describe Flashcards::ForkDeckService do
  def create_user(prefix: "u")
    User.create!(
      email_address: "#{prefix}#{SecureRandom.hex(3)}@example.com",
      nickname:      "#{prefix}#{SecureRandom.hex(3)}",
      password:      "password",
      role:          :user,
      sport_level:   :beginner,
      age_group:     :twenties,
      gender:        :unspecified
    )
  end

  let(:user) { create_user(prefix: "forker") }
  let(:source) do
    Deck.create!(
      scope:       :official,
      owner:       nil,
      title:       "공식 원본 #{SecureRandom.hex(3)}",
      description: "공식 덱 설명",
      category:    :science_technology
    )
  end

  describe "happy path with 5 ordered cards" do
    before do
      5.times do |i|
        Card.create!(
          deck: source,
          front: "F#{i + 1}",
          back:  "B#{i + 1}",
          hint:  "H#{i + 1}",
          tags:  "tag#{i + 1}",
          position: i + 1
        )
      end
    end

    it "returns Result(success?: true) with a new personal Deck owned by user" do
      result = described_class.call(source: source, user: user)

      expect(result.success?).to be true
      expect(result.errors).to be_empty
      expect(result.deck).to be_a(Deck)
      expect(result.deck.scope).to eq("personal")
      expect(result.deck.owner).to eq(user)
      expect(result.deck.forked_from).to eq(source)
      expect(result.deck.forked_from_deck_id).to eq(source.id)
      expect(result.deck.title).to eq(source.title)
      expect(result.deck.description).to eq(source.description)
      expect(result.deck.category).to eq(source.category)
    end

    it "copies all 5 cards with contiguous positions 1..5" do
      result = described_class.call(source: source, user: user)
      new_cards = result.deck.cards.ordered

      expect(new_cards.count).to eq(5)
      expect(new_cards.pluck(:position)).to eq([ 1, 2, 3, 4, 5 ])
    end

    it "copies card content (front/back/hint/tags)" do
      result = described_class.call(source: source, user: user)
      src_cards = source.cards.ordered.to_a
      new_cards = result.deck.cards.ordered.to_a

      new_cards.each_with_index do |card, i|
        expect(card.front).to eq(src_cards[i].front)
        expect(card.back).to  eq(src_cards[i].back)
        expect(card.hint).to  eq(src_cards[i].hint)
        expect(card.tags).to  eq(src_cards[i].tags)
      end
    end

    it "does NOT create any CardReview rows for the new deck (ADR-0001)" do
      result = described_class.call(source: source, user: user)
      expect(CardReview.where(user: user, card_id: result.deck.cards.ids).count).to eq(0)
    end
  end

  describe "position renormalization (PITFALLS §7)" do
    before do
      [ 1, 3, 5, 10 ].each do |pos|
        Card.create!(deck: source, front: "F#{pos}", back: "B#{pos}", position: pos)
      end
    end

    it "renormalizes non-contiguous source positions to 1..n contiguous" do
      result = described_class.call(source: source, user: user)
      expect(result.deck.cards.ordered.pluck(:position)).to eq([ 1, 2, 3, 4 ])
    end
  end

  describe "CardReview isolation" do
    let!(:src_card) { Card.create!(deck: source, front: "F", back: "B", position: 1) }
    let!(:pre_existing_review) do
      CardReview.create!(
        user: user, card: src_card, ease: 2.0, interval_days: 30, repetitions: 5
      )
    end

    it "preserves pre-existing CardReview on the source untouched" do
      described_class.call(source: source, user: user)
      pre_existing_review.reload
      expect(pre_existing_review.ease).to eq(2.0)
      expect(pre_existing_review.interval_days).to eq(30)
      expect(pre_existing_review.repetitions).to eq(5)
      expect(pre_existing_review.card_id).to eq(src_card.id)
    end

    it "does NOT create a CardReview for the new deck's card" do
      result = described_class.call(source: source, user: user)
      new_card = result.deck.cards.first
      expect(CardReview.where(user: user, card: new_card).count).to eq(0)
    end
  end

  describe "empty source deck" do
    it "returns success with zero cards" do
      result = described_class.call(source: source, user: user)
      expect(result.success?).to be true
      expect(result.deck.cards.count).to eq(0)
    end
  end

  describe "transactional rollback on card create failure" do
    before do
      3.times do |i|
        Card.create!(deck: source, front: "F#{i + 1}", back: "B#{i + 1}", position: i + 1)
      end
    end

    it "rolls back Deck and Card inserts when the 3rd card save fails" do
      call_count = 0
      allow_any_instance_of(Card).to receive(:save!).and_wrap_original do |orig, *args, **kwargs|
        call_count += 1
        if call_count == 3
          raise ActiveRecord::RecordInvalid.new(Card.new.tap { |c| c.errors.add(:base, "boom") })
        else
          orig.call(*args, **kwargs)
        end
      end

      deck_count_before = Deck.count
      card_count_before = Card.count

      result = described_class.call(source: source, user: user)

      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
      expect(Deck.count).to eq(deck_count_before)
      expect(Card.count).to eq(card_count_before)
    end
  end
end
