# app/queries/flashcards/mastery_query.rb
# frozen_string_literal: true

module Flashcards
  class MasteryQuery
    MASTERY_INTERVAL_DAYS = 21

    def self.call(user:, deck:)
      new(user: user, deck: deck).call
    end

    def initialize(user:, deck:)
      @user = user
      @deck = deck
    end

    def call
      total = @deck.cards.count
      return 0.0 if total.zero?

      mastered = @deck.cards
                      .joins(:card_reviews)
                      .where(card_reviews: { user: @user })
                      .where("card_reviews.interval_days >= ?", MASTERY_INTERVAL_DAYS)
                      .count

      mastered.to_f / total
    end
  end
end
