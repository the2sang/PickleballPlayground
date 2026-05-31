require "rails_helper"

RSpec.describe CardReview, type: :model do
  let(:user) do
    User.create!(
      email_address: "cr_user#{SecureRandom.hex(3)}@example.com",
      nickname:      "cruser#{SecureRandom.hex(3)}",
      password:      "password",
      role:          :user,
      sport_level:   :beginner,
      age_group:     :twenties,
      gender:        :unspecified
    )
  end

  let(:deck) { Deck.create!(scope: :personal, owner: user, title: "덱") }
  let(:card) { Card.create!(deck: deck, front: "F", back: "B", position: 1) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:card) }
  end

  describe "validations" do
    subject do
      CardReview.new(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0)
    end

    it { is_expected.to validate_uniqueness_of(:card_id).scoped_to(:user_id) }
    it { is_expected.to validate_numericality_of(:ease).is_greater_than_or_equal_to(1.3) }
    it { is_expected.to validate_numericality_of(:interval_days).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:repetitions).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "ease default" do
    it "defaults to 2.5 from DB" do
      cr = CardReview.create!(user: user, card: card, interval_days: 0, repetitions: 0)
      expect(cr.ease).to eq(2.5)
    end
  end

  describe "last_rating range" do
    it "allows nil" do
      cr = CardReview.new(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0, last_rating: nil)
      expect(cr).to be_valid
    end

    it "allows 1..4" do
      (1..4).each do |r|
        cr = CardReview.new(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0, last_rating: r)
        expect(cr).to be_valid, "expected last_rating=#{r} to be valid"
      end
    end

    it "rejects 0" do
      cr = CardReview.new(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0, last_rating: 0)
      expect(cr).not_to be_valid
      expect(cr.errors[:last_rating]).to be_present
    end

    it "rejects 5" do
      cr = CardReview.new(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0, last_rating: 5)
      expect(cr).not_to be_valid
      expect(cr.errors[:last_rating]).to be_present
    end
  end

  describe "critical indexes (F1-IDX)" do
    let(:idxs) { CardReview.connection.indexes(:card_reviews).map(&:columns) }

    it "includes (user_id, next_review_at) composite index" do
      expect(idxs).to include([ "user_id", "next_review_at" ])
    end

    it "includes unique (user_id, card_id) index" do
      expect(idxs).to include([ "user_id", "card_id" ])
    end
  end
end
