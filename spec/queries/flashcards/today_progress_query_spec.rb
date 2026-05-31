# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flashcards::TodayProgressQuery, type: :query do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  subject { described_class.call(user: user) }

  def review_at(utc_time)
    create(:card_review, user: user, card: card,
           updated_at: utc_time, created_at: utc_time,
           last_rating: 3, interval_days: 1, repetitions: 1,
           next_review_at: 1.day.from_now)
  end

  context "오늘 KST에 학습한 카드 1장" do
    before { review_at(Time.current) }

    it "reviewed_today = 1" do
      expect(subject[:reviewed_today]).to eq(1)
    end
  end

  context "어제 UTC에 학습 (KST 기준 오늘이 아님)" do
    before { review_at(Time.current - 1.day) }

    it "reviewed_today = 0" do
      expect(subject[:reviewed_today]).to eq(0)
    end
  end

  context "due 카드 있음" do
    before do
      create(:card_review, :due, user: user, card: card)
    end

    it "due_remaining > 0" do
      expect(subject[:due_remaining]).to be > 0
    end
  end

  context "접근 불가 덱 카드는 due_remaining에 포함 안 됨" do
    let(:other_user) { create(:user) }
    let(:private_deck) { create(:deck, :personal, owner: other_user) }
    before do
      private_card = create(:card, deck: private_deck)
      create(:card_review, :due, user: user, card: private_card)
    end

    it "타 사용자 personal 덱의 due 카드는 제외된다" do
      expect(subject[:due_remaining]).to eq(0)
    end
  end

  context "CardReview 없는 유저" do
    it "{ reviewed_today: 0, due_remaining: 0 } — 접근 가능 덱도 없음" do
      expect(subject).to eq({ reviewed_today: 0, due_remaining: 0 })
    end
  end
end
