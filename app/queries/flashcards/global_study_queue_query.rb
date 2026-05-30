# frozen_string_literal: true

module Flashcards
  class GlobalStudyQueueQuery
    NEW_CARD_LIMIT = 10

    def initialize(user:)
      @user = user
    end

    def call
      accessible_decks = DeckPolicy::Scope.new(user, Deck.all).resolve

      Card.where(deck: accessible_decks)
          .joins(join_clause)
          .where("card_reviews.id IS NULL OR card_reviews.next_review_at IS NULL OR card_reviews.next_review_at <= ?", Time.current)
          .order(Arel.sql("card_reviews.next_review_at ASC NULLS FIRST, cards.position ASC, cards.id ASC"))
          .limit(NEW_CARD_LIMIT)
    end

    private

    attr_reader :user

    def join_clause
      sanitized_id = ActiveRecord::Base.connection.quote(user.id)
      "LEFT OUTER JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = #{sanitized_id}"
    end
  end
end
