# app/queries/flashcards/due_forecast_query.rb
# frozen_string_literal: true

module Flashcards
  class DueForecastQuery
    FORECAST_DAYS = 7

    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      today_kst        = Time.current.in_time_zone("Asia/Seoul").to_date
      end_kst          = today_kst + (FORECAST_DAYS - 1).days
      accessible_decks = DeckPolicy::Scope.new(@user, Deck.all).resolve

      rows = CardReview.joins(:card)
                       .where(cards: { deck_id: accessible_decks })
                       .where(user: @user)
                       .where.not(next_review_at: nil)
                       .where(
                         "DATE(DATETIME(card_reviews.next_review_at, '+9 hours')) BETWEEN ? AND ?",
                         today_kst.to_s, end_kst.to_s
                       )
                       .group(Arel.sql("DATE(DATETIME(card_reviews.next_review_at, '+9 hours'))"))
                       .count

      (today_kst..end_kst).map do |date|
        { date: date, count: rows[date.to_s] || 0 }
      end
    end
  end
end
