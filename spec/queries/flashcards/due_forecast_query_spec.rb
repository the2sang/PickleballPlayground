# spec/queries/flashcards/due_forecast_query_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flashcards::DueForecastQuery, type: :query do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  subject { described_class.call(user: user) }

  context "due 카드 없음" do
    it "7개 날짜, 모든 count = 0" do
      expect(subject.length).to eq(7)
      expect(subject.map { |r| r[:count] }.sum).to eq(0)
    end
  end

  context "오늘+3일 후에 각 1장씩 due" do
    before do
      today_kst = Time.current.in_time_zone("Asia/Seoul").to_date
      [ 0, 3 ].each do |offset|
        c = create(:card, deck: deck)
        due_utc = (today_kst + offset.days).to_time.in_time_zone("Asia/Seoul").noon.utc
        create(:card_review, user: user, card: c,
               next_review_at: due_utc, interval_days: 1, repetitions: 1,
               ease: 2.5, last_rating: 3, last_reviewed_at: 1.day.ago)
      end
    end

    it "오늘 및 3일 후 count = 1, 나머지 0" do
      today_kst = Time.current.in_time_zone("Asia/Seoul").to_date
      today_row = subject.find { |r| r[:date] == today_kst }
      plus3_row = subject.find { |r| r[:date] == today_kst + 3.days }

      expect(today_row[:count]).to eq(1)
      expect(plus3_row[:count]).to eq(1)
      expect(subject.reject { |r| r[:date].in?([ today_kst, today_kst + 3.days ]) }
                    .map { |r| r[:count] }.sum).to eq(0)
    end
  end

  context "8일 후 due 카드 — 범위 외" do
    before do
      c = create(:card, deck: deck)
      due_utc = (Time.current.in_time_zone("Asia/Seoul").to_date + 8.days)
                  .to_time.in_time_zone("Asia/Seoul").noon.utc
      create(:card_review, user: user, card: c,
             next_review_at: due_utc, interval_days: 8, repetitions: 2,
             ease: 2.5, last_rating: 3, last_reviewed_at: 1.day.ago)
    end

    it "7일 범위에 포함되지 않음" do
      expect(subject.map { |r| r[:count] }.sum).to eq(0)
    end
  end

  context "DeckPolicy::Scope — 타 사용자 personal 덱 카드는 포함 안 됨" do
    let(:other_user) { create(:user) }
    let(:other_deck) { create(:deck, :personal, owner: other_user) }
    before do
      c = create(:card, deck: other_deck)
      create(:card_review, user: user, card: c,
             next_review_at: Time.current + 1.hour, interval_days: 1, repetitions: 1,
             ease: 2.5, last_rating: 3, last_reviewed_at: 1.day.ago)
    end

    it "접근 불가 덱의 카드는 포함되지 않는다" do
      expect(subject.map { |r| r[:count] }.sum).to eq(0)
    end
  end

  context "단일 쿼리 검증" do
    before do
      c = create(:card, deck: deck)
      create(:card_review, user: user, card: c,
             next_review_at: Time.current + 2.hours, interval_days: 1, repetitions: 1,
             ease: 2.5, last_rating: 3, last_reviewed_at: 1.day.ago)
    end

    it "DeckPolicy::Scope 해석 포함 2쿼리 이내" do
      query_count = 0
      counter = ->(*, payload) { query_count += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        described_class.call(user: user)
      end
      expect(query_count).to be <= 2
    end
  end
end
