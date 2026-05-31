require "rails_helper"

RSpec.describe Deck, type: :model do
  let(:user) do
    User.create!(
      email_address: "deck_user#{SecureRandom.hex(3)}@example.com",
      nickname:      "deckuser#{SecureRandom.hex(3)}",
      password:      "password",
      role:          :user,
      sport_level:   :beginner,
      age_group:     :twenties,
      gender:        :unspecified
    )
  end

  let(:club_owner) do
    User.create!(
      email_address: "club_owner#{SecureRandom.hex(3)}@example.com",
      nickname:      "clubowner#{SecureRandom.hex(3)}",
      password:      "password",
      role:          :user,
      sport_level:   :beginner,
      age_group:     :twenties,
      gender:        :unspecified
    )
  end

  let(:club) do
    Club.create!(name: "테스트 클럽 #{SecureRandom.hex(3)}", owner: club_owner, status: :approved)
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(200) }
    it { is_expected.to validate_length_of(:description).is_at_most(2000) }
  end

  describe "associations" do
    it "has a polymorphic optional :owner association" do
      assoc = Deck.reflect_on_association(:owner)
      expect(assoc.options[:polymorphic]).to be true
      expect(assoc.options[:optional]).to be true
    end
    it { is_expected.to belong_to(:forked_from).class_name("Deck").optional }
    it { is_expected.to have_many(:forks).class_name("Deck").with_foreign_key(:forked_from_deck_id) }
    it { is_expected.to have_many(:cards).dependent(:destroy) }
    it { is_expected.to have_many(:tournament_event_decks).dependent(:destroy) }
    it { is_expected.to have_many(:tournament_events).through(:tournament_event_decks) }
  end

  describe "enum :scope" do
    it "exposes class scopes" do
      expect(Deck).to respond_to(:official)
      expect(Deck).to respond_to(:club)
      expect(Deck).to respond_to(:personal)
    end

    it "exposes predicates" do
      personal_deck = Deck.new(scope: :personal, owner: user, title: "p")
      expect(personal_deck.personal?).to be true
      expect(personal_deck.official?).to be false
    end

    it "defaults to :personal" do
      expect(Deck.new.scope).to eq("personal")
    end
  end

  describe "enum :category" do
    it "uses 기타 as the default representative category" do
      expect(Deck.new.category).to eq("other")
    end

    it "exposes Korean category options with all filter" do
      expect(Deck.category_options(include_all: true)).to include([ "전체", 0 ])
      expect(Deck.category_options).to include([ "1. 정치/경제", 1 ], [ "5. 언어", 5 ])
    end
  end

  describe "owner_matches_scope validation" do
    it "rejects official deck with non-nil owner" do
      deck = Deck.new(scope: :official, owner: user, title: "공식")
      expect(deck).not_to be_valid
      expect(deck.errors[:owner]).to be_present
    end

    it "accepts official deck with nil owner" do
      deck = Deck.new(scope: :official, owner: nil, title: "공식")
      expect(deck).to be_valid
    end

    it "rejects club deck owned by a non-Club" do
      deck = Deck.new(scope: :club, owner: user, title: "클럽")
      expect(deck).not_to be_valid
      expect(deck.errors[:owner]).to be_present
    end

    it "accepts club deck owned by a Club" do
      deck = Deck.new(scope: :club, owner: club, title: "클럽")
      expect(deck).to be_valid
    end

    it "rejects personal deck with nil owner" do
      deck = Deck.new(scope: :personal, owner: nil, title: "개인")
      expect(deck).not_to be_valid
      expect(deck.errors[:owner]).to be_present
    end

    it "accepts personal deck owned by a User" do
      deck = Deck.new(scope: :personal, owner: user, title: "개인")
      expect(deck).to be_valid
    end
  end

  describe ".featured scope" do
    it "returns decks with featured_at set, ordered descending" do
      earlier = Deck.create!(scope: :official, owner: nil, title: "공식1", featured_at: 2.days.ago)
      later   = Deck.create!(scope: :official, owner: nil, title: "공식2", featured_at: 1.day.ago)
      Deck.create!(scope: :official, owner: nil, title: "공식3", featured_at: nil)

      featured = Deck.featured
      expect(featured.to_a).to eq([ later, earlier ])
    end
  end

  describe "dependent: :destroy on cards" do
    it "destroys child cards when deck is destroyed" do
      deck = Deck.create!(scope: :personal, owner: user, title: "삭제 테스트")
      Card.create!(deck: deck, front: "F1", back: "B1", position: 1)
      Card.create!(deck: deck, front: "F2", back: "B2", position: 2)

      expect { deck.destroy! }.to change { Card.count }.by(-2)
    end
  end

  describe "personal deck limits" do
    it "rejects the eleventh personal deck until an addition request is approved" do
      Deck::PERSONAL_DECK_LIMIT.times do |index|
        Deck.create!(scope: :personal, owner: user, title: "개인 #{index}")
      end

      extra = Deck.new(scope: :personal, owner: user, title: "추가 덱")
      expect(extra).not_to be_valid
      expect(extra.errors[:base].join).to include("덱 추가 승인요청")

      create(:deck_addition_request, :approved, user: user)
      expect(extra).to be_valid
    end

    it "rejects a personal deck larger than 1MB" do
      deck = Deck.new(
        scope: :personal,
        owner: user,
        title: "큰 덱",
        description: "x" * (Deck::PERSONAL_DECK_SIZE_LIMIT_BYTES + 1)
      )

      expect(deck).not_to be_valid
      expect(deck.errors[:base].join).to include("1MB")
    end
  end
end
