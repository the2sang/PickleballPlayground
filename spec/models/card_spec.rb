require "rails_helper"

RSpec.describe Card, type: :model do
  let(:user) do
    User.create!(
      email_address: "card_user#{SecureRandom.hex(3)}@example.com",
      nickname:      "carduser#{SecureRandom.hex(3)}",
      password:      "password",
      role:          :user,
      sport_level:   :beginner,
      age_group:     :twenties,
      gender:        :unspecified
    )
  end

  let(:deck) { Deck.create!(scope: :personal, owner: user, title: "테스트 덱") }

  describe "associations" do
    it { is_expected.to belong_to(:deck) }
    it { is_expected.to have_many(:card_reviews).dependent(:destroy) }
  end

  describe "validations" do
    subject { Card.new(deck: deck, front: "F", back: "B", position: 1) }
    it { is_expected.to validate_presence_of(:front) }
    it { is_expected.to validate_presence_of(:back) }
    it { is_expected.to validate_length_of(:front).is_at_most(2000) }
    it { is_expected.to validate_length_of(:back).is_at_most(2000) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "enum :card_type" do
    it "defaults to :basic with integer 0" do
      card = Card.new
      expect(card.card_type).to eq("basic")
      expect(Card.card_types["basic"]).to eq(0)
    end

    it "exposes class scope" do
      expect(Card).to respond_to(:basic)
    end

    it "supports uploaded multiple choice cards" do
      card = Card.new(
        deck: deck,
        front: "문제",
        back: "정답",
        card_type: :multiple_choice,
        answer_choices: [ "오답1", "오답2", "오답3" ],
        position: 1
      )

      expect(card).to be_valid
      expect(card).to be_multiple_choice
      expect(Card.card_types["multiple_choice"]).to eq(1)
    end
  end

  describe "#quiz_options" do
    it "uses stored answer choices for multiple choice cards" do
      card = Card.create!(
        deck: deck,
        front: "문제",
        back: "정답",
        card_type: :multiple_choice,
        answer_choices: [ "오답1", "오답2", "오답3" ],
        position: 1
      )

      expect(card.quiz_options(deck)).to contain_exactly("정답", "오답1", "오답2", "오답3")
    end

    it "requires three wrong choices for multiple choice cards" do
      card = Card.new(
        deck: deck,
        front: "문제",
        back: "정답",
        card_type: :multiple_choice,
        answer_choices: [ "오답1" ],
        position: 1
      )

      expect(card).not_to be_valid
      expect(card.errors[:answer_choices].join).to include("오답 선택지 3개")
    end
  end

  describe "ActiveStorage attachments" do
    it "declares has_one_attached :front_image" do
      expect(Card.new).to respond_to(:front_image)
    end

    it "declares has_one_attached :back_image" do
      expect(Card.new).to respond_to(:back_image)
    end
  end

  describe "image validation" do
    let(:card) { Card.create!(deck: deck, front: "F", back: "B", position: 1) }

    it "rejects non-allowed content_type with Korean message" do
      card.front_image.attach(io: StringIO.new("not an image"), filename: "bad.txt", content_type: "text/plain")
      expect(card).not_to be_valid
      expect(card.errors[:front_image].join).to include("허용되지 않은 이미지 형식")
    end

    it "rejects oversized image (>5MB)" do
      big_bytes = "x" * (5.megabytes + 1)
      card.front_image.attach(io: StringIO.new(big_bytes), filename: "big.png", content_type: "image/png")
      expect(card).not_to be_valid
      expect(card.errors[:front_image].join).to include("이미지가 너무 큽니다")
    end

    it "accepts small PNG within limits" do
      card.front_image.attach(io: StringIO.new("png-data"), filename: "ok.png", content_type: "image/png")
      expect(card).to be_valid
    end
  end

  describe ".ordered scope" do
    it "orders by position then id" do
      c2 = Card.create!(deck: deck, front: "F2", back: "B2", position: 2)
      c1 = Card.create!(deck: deck, front: "F1", back: "B1", position: 1)
      c3 = Card.create!(deck: deck, front: "F3", back: "B3", position: 3)

      expect(deck.cards.ordered.to_a).to eq([ c1, c2, c3 ])
    end
  end

  describe "cascade to card_reviews on destroy" do
    it "deletes child card_reviews when card is destroyed" do
      card = Card.create!(deck: deck, front: "F", back: "B", position: 1)
      other_user = User.create!(
        email_address: "cr_user#{SecureRandom.hex(3)}@example.com",
        nickname:      "cruser#{SecureRandom.hex(3)}",
        password:      "password",
        role:          :user,
        sport_level:   :beginner,
        age_group:     :twenties,
        gender:        :unspecified
      )

      CardReview.create!(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0)
      CardReview.create!(user: other_user, card: card, ease: 2.5, interval_days: 0, repetitions: 0)

      expect { card.destroy! }.to change { CardReview.count }.by(-2)
    end
  end
end
