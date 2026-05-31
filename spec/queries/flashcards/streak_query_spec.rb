# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flashcards::StreakQuery, type: :query do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  subject { described_class.call(user: user) }

  def review_on(kst_date, card: self.card)
    utc_time = kst_date.to_time.in_time_zone("Asia/Seoul").beginning_of_day.utc
    create(:card_review, user: user, card: card,
           updated_at: utc_time, created_at: utc_time,
           last_rating: 3, interval_days: 1, repetitions: 1,
           next_review_at: 1.day.from_now)
  end

  context "오늘만 학습" do
    before { review_on(Date.current) }
    it "streak = 1" do
      expect(subject).to eq(1)
    end
  end

  context "어제 + 오늘 학습" do
    before do
      review_on(Date.current - 1.day)
      new_card = create(:card, deck: deck)
      review_on(Date.current, card: new_card)
    end
    it "streak = 2" do
      expect(subject).to eq(2)
    end
  end

  context "어제만 학습 (오늘 안 함)" do
    before { review_on(Date.current - 1.day) }
    it "streak = 1 (streak 유지)" do
      expect(subject).to eq(1)
    end
  end

  context "그저께까지 학습, 어제 건름" do
    before do
      card2 = create(:card, deck: deck)
      review_on(Date.current - 2.days)
      review_on(Date.current - 3.days, card: card2)
    end
    it "streak = 0 (하루 빠지면 리셋)" do
      expect(subject).to eq(0)
    end
  end

  context "CardReview 없음" do
    it "streak = 0" do
      expect(subject).to eq(0)
    end
  end

  context "23:58 KST에 학습 → 00:01 KST streak 유지" do
    before do
      kst_yesterday_2358 = (Date.current - 1.day).to_time.in_time_zone("Asia/Seoul").end_of_day - 2.minutes
      create(:card_review, user: user, card: card,
             updated_at: kst_yesterday_2358.utc, created_at: kst_yesterday_2358.utc,
             last_rating: 3, interval_days: 1, repetitions: 1, next_review_at: 1.day.from_now)
    end
    it "자정 이후에도 어제 streak 유지" do
      travel_to Time.current.in_time_zone("Asia/Seoul").beginning_of_day + 1.minute do
        expect(described_class.call(user: user)).to eq(1)
      end
    end
  end
end
