class Decks::StudiesController < ApplicationController
  before_action :set_deck

  def show
    authorize @deck, :show?
    @due_cards = Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
    if @due_cards.empty?
      render :complete
    else
      @current_card = @due_cards.first
      @total_count = @deck.cards.count
      @completed_count = @total_count - @due_cards.size
      @options = @current_card.quiz_options(@deck)
    end
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
