class Decks::BrowsesController < ApplicationController
  def show
    @deck = Deck.find(params[:deck_id])
    authorize @deck, :show?
    @cards = @deck.cards.order(:position, :id)
    @cards_json = @cards.as_json(only: %i[id front back])
  end
end
