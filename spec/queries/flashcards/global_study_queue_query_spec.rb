# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flashcards::GlobalStudyQueueQuery, type: :query do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  subject { described_class.new(user: user).call }

  context "personal 덱 (owner=user) due 카드 — 포함" do
    let!(:personal_deck) { create(:deck, :personal, owner: user) }
    let!(:card)          { create(:card, deck: personal_deck) }
    let!(:due_review)    { create(:card_review, :due, user: user, card: card) }

    it "큐에 포함된다" do
      expect(subject).to include(card)
    end
  end

  context "personal 덱 (owner=user) 신규 카드 (CardReview 미존재) — 포함" do
    let!(:personal_deck) { create(:deck, :personal, owner: user) }
    let!(:card)          { create(:card, deck: personal_deck) }

    it "신규 카드(CardReview 없음)는 due로 취급된다" do
      expect(subject).to include(card)
    end
  end

  context "official 덱 due 카드 — 포함" do
    let!(:official_deck) { create(:deck, :official) }
    let!(:card)          { create(:card, deck: official_deck) }

    it "official 덱의 신규 카드가 큐에 포함된다" do
      expect(subject).to include(card)
    end

    it "official 덱의 due 카드(CardReview 존재)가 큐에 포함된다" do
      create(:card_review, :due, user: user, card: card)
      expect(subject).to include(card)
    end
  end

  context "club 덱 — 항상 제외 (Phase 4 deferred, T-03-04 회귀 가드)" do
    let!(:club)      { create(:club) }
    let!(:club_deck) { create(:deck, :club, owner: club) }
    let!(:club_card) { create(:card, deck: club_deck) }

    it "club 덱의 카드는 큐에 포함되지 않는다" do
      expect(subject).not_to include(club_card)
    end

    it "club 덱의 due 카드도 큐에 포함되지 않는다" do
      create(:card_review, :due, user: user, card: club_card)
      expect(subject).not_to include(club_card)
    end
  end

  context "타 사용자 personal 덱 — 제외" do
    let!(:other_deck) { create(:deck, :personal, owner: other_user) }
    let!(:other_card) { create(:card, deck: other_deck) }

    it "타 사용자 personal 덱의 카드는 큐에 포함되지 않는다" do
      expect(subject).not_to include(other_card)
    end
  end

  context "mature CardReview (next_review_at 미래) — 제외" do
    let!(:personal_deck) { create(:deck, :personal, owner: user) }
    let!(:card)          { create(:card, deck: personal_deck) }
    let!(:mature_review) { create(:card_review, :mature, user: user, card: card) }

    it "mature 카드는 큐에서 제외된다" do
      expect(subject).not_to include(card)
    end
  end

  context "next_review_at <= Time.current 인 CardReview 카드 — 포함" do
    let!(:personal_deck) { create(:deck, :personal, owner: user) }
    let!(:card)          { create(:card, deck: personal_deck) }
    let!(:due_review)    { create(:card_review, :due, user: user, card: card) }

    it "next_review_at이 과거인 카드는 포함된다" do
      expect(subject).to include(card)
    end
  end

  context "정렬 검증 (next_review_at ASC NULLS FIRST)" do
    let!(:personal_deck) { create(:deck, :personal, owner: user) }
    let!(:card_new)      { create(:card, deck: personal_deck, position: 2) }
    let!(:card_old)      { create(:card, deck: personal_deck, position: 1) }
    let!(:card_medium)   { create(:card, deck: personal_deck, position: 3) }

    before do
      create(:card_review, user: user, card: card_old,
             ease: 2.5, interval_days: 1, repetitions: 1,
             next_review_at: 3.hours.ago, last_reviewed_at: 1.day.ago, last_rating: 3)
      create(:card_review, user: user, card: card_medium,
             ease: 2.5, interval_days: 1, repetitions: 1,
             next_review_at: 1.hour.ago, last_reviewed_at: 1.day.ago, last_rating: 3)
      # card_new has no CardReview → NULLS FIRST
    end

    it "신규 카드(NULLS FIRST)가 먼저, 그 다음 오래된 due 카드 순으로 정렬된다" do
      result = subject.to_a
      expect(result.index(card_new)).to be < result.index(card_old)
    end
  end

  context "LIMIT 10" do
    let!(:personal_deck) { create(:deck, :personal, owner: user) }

    before do
      11.times { create(:card, deck: personal_deck) }
    end

    it "최대 10개만 반환된다" do
      expect(subject.count).to eq(10)
    end
  end

  context "접근 가능 덱 없는 유저 — 빈 Relation" do
    it "due 카드가 없으면 빈 Relation을 반환한다" do
      expect(subject).to be_empty
    end
  end
end
