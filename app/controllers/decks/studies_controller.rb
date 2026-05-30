class Decks::StudiesController < ApplicationController
  before_action :set_deck

  def show
    authorize @deck, :show?

    repeat = params[:repeat].present?

    @due_cards = if repeat
                   @deck.cards
    else
                   Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
    end

    if @due_cards.empty?
      render :complete
      return
    end

    # Discard any abandoned in-progress session for this user+deck
    StudySession.where(user: Current.user, deck: @deck, completed_at: nil).destroy_all

    @study_session = StudySession.create!(
      user:   Current.user,
      deck:   @deck,
      repeat: repeat
    )

    @current_card    = @due_cards.first
    @total_count     = @deck.cards.count
    @completed_count = 0
    @options         = @current_card.quiz_options(@deck)
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
