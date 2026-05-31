# spec/queries/flashcards/mastery_query_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flashcards::MasteryQuery, type: :query do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }

  subject { described_class.call(user: user, deck: deck) }

  context "빈 덱" do
    it "0.0을 반환한다 (division-by-zero 가드)" do
      expect(subject).to eq(0.0)
    end
  end

  context "카드는 있지만 CardReview 없음" do
    before { create(:card, deck: deck) }
    it "0.0" do
      expect(subject).to eq(0.0)
    end
  end

  context "1/2 카드가 숙련됨 (interval_days >= 21)" do
    before do
      card_mature = create(:card, deck: deck)
      card_new    = create(:card, deck: deck)
      create(:card_review, :mature, user: user, card: card_mature)
      create(:card_review, user: user, card: card_new, interval_days: 5)
    end
    it "0.5를 반환한다" do
      expect(subject).to eq(0.5)
    end
  end

  context "모든 카드 숙련됨" do
    before do
      2.times do
        c = create(:card, deck: deck)
        create(:card_review, :mature, user: user, card: c)
      end
    end
    it "1.0을 반환한다" do
      expect(subject).to eq(1.0)
    end
  end

  context "다른 사용자의 CardReview는 포함하지 않음" do
    let(:other_user) { create(:user) }
    before do
      card = create(:card, deck: deck)
      create(:card_review, :mature, user: other_user, card: card)
    end
    it "0.0 (자기 review만 집계)" do
      expect(subject).to eq(0.0)
    end
  end

  context "interval_days = 20 — 경계값, 숙련 아님" do
    before do
      card = create(:card, deck: deck)
      create(:card_review, user: user, card: card, interval_days: 20)
    end
    it "0.0" do
      expect(subject).to eq(0.0)
    end
  end

  context "interval_days = 21 — 숙련 경계값" do
    before do
      card = create(:card, deck: deck)
      create(:card_review, user: user, card: card, interval_days: 21,
             ease: 2.5, repetitions: 5, next_review_at: 21.days.from_now,
             last_reviewed_at: 1.day.ago, last_rating: 3)
    end
    it "1.0" do
      expect(subject).to eq(1.0)
    end
  end
end
