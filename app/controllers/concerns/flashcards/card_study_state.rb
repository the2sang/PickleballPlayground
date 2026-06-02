module Flashcards::CardStudyState
  extend ActiveSupport::Concern

  private

  def set_card_study_state(card)
    @card_difficulty = UserCardRating.find_by(user: Current.user, card: card)&.difficulty
    @card_bookmarked = CardBookmark.exists?(user: Current.user, card: card)
  end
end
