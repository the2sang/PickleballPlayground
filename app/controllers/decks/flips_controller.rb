class Decks::FlipsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :resume_session, only: :show

  def show
    @deck = Deck.find(params[:deck_id])
    authorize @deck, :show?

    @min_stars = params[:min_stars].to_i
    @cards = if @min_stars.between?(1, 5)
      @deck.cards
           .joins(:user_card_ratings)
           .where(user_card_ratings: { user: Current.user, difficulty: @min_stars.. })
           .order(:position)
    else
      @deck.cards.order(:position)
    end

    @cards_json = @cards.as_json(only: %i[id front back])
    @ratings    = UserCardRating.where(user: Current.user, card: @cards)
                                .pluck(:card_id, :difficulty).to_h
  end
end
