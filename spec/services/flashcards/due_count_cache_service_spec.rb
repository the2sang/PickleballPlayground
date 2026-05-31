# spec/services/flashcards/due_count_cache_service_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flashcards::DueCountCacheService do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  before { Rails.cache.clear }
  after  { Rails.cache.clear }

  describe ".fetch" do
    context "캐시 miss — DB에서 계산" do
      before do
        create(:card_review, :due, user: user, card: card)
      end

      it "due_remaining 정수를 반환한다" do
        result = described_class.fetch(user)
        expect(result).to be_a(Integer)
        expect(result).to be >= 1
      end
    end

    context "캐시 hit — 같은 값 반환" do
      before { described_class.fetch(user) }

      it "두 번째 호출도 같은 값을 반환한다" do
        result1 = described_class.fetch(user)
        result2 = described_class.fetch(user)
        expect(result1).to eq(result2)
      end
    end
  end

  describe ".invalidate" do
    it "캐시를 비워 다음 fetch 시 재계산되도록 한다" do
      described_class.fetch(user)

      create(:card_review, :due, user: user, card: create(:card, deck: deck))
      described_class.invalidate(user)

      fresh = described_class.fetch(user)
      expect(fresh).to be >= 1
    end
  end
end
