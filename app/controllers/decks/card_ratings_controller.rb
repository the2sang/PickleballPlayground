class Decks::CardRatingsController < ApplicationController
  before_action :set_deck

  def create
    card = @deck.cards.find(params[:card_id])
    authorize @deck, :show?

    rating = UserCardRating.find_or_initialize_by(user: Current.user, card: card)
    rating.update!(difficulty: params[:difficulty].to_i.clamp(1, 5))

    head :ok
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
