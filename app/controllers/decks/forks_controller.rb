class Decks::ForksController < ApplicationController
  before_action :set_deck

  def create
    authorize @deck, :fork?

    result = Flashcards::ForkDeckService.call(source: @deck, user: Current.user)

    if result.success?
      redirect_to deck_path(result.deck), notice: "덱을 내 학습 덱으로 복제했습니다."
    else
      redirect_to deck_path(@deck), alert: result.errors.join(", ")
    end
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
