class Decks::CardBookmarksController < ApplicationController
  before_action :set_deck
  before_action :set_card

  def create
    authorize @deck, :show?

    CardBookmark.find_or_create_by!(user: Current.user, card: @card)
    head :ok
  end

  def destroy
    authorize @deck, :show?

    CardBookmark.where(user: Current.user, card: @card).destroy_all
    head :ok
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def set_card
    @card = @deck.cards.find(params[:card_id])
  end
end
