# frozen_string_literal: true

module Flashcards
  class TodayProgressQuery
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      today_kst = Time.current.in_time_zone("Asia/Seoul").to_date

      reviewed_today = CardReview.where(user: @user)
                                 .where("DATE(DATETIME(updated_at, '+9 hours')) = ?", today_kst.to_s)
                                 .count

      accessible_decks = DeckPolicy::Scope.new(@user, Deck.all).resolve
      sanitized_id     = ActiveRecord::Base.connection.quote(@user.id)
      join_clause      = "LEFT OUTER JOIN card_reviews ON card_reviews.card_id = cards.id AND card_reviews.user_id = #{sanitized_id}"

      due_remaining = Card.where(deck: accessible_decks)
                          .joins(join_clause)
                          .where("card_reviews.id IS NULL OR card_reviews.next_review_at IS NULL OR card_reviews.next_review_at <= ?", Time.current)
                          .count

      { reviewed_today: reviewed_today, due_remaining: due_remaining }
    end
  end
end
