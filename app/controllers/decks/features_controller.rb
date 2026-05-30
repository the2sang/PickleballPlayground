class Decks::FeaturesController < ApplicationController
  before_action :set_deck

  def create
    authorize @deck, :feature?
    @deck.update!(featured_at: Time.current)
    redirect_to deck_path(@deck), notice: "덱을 피처드로 설정했습니다."
  end

  def destroy
    authorize @deck, :feature?
    @deck.update!(featured_at: nil)
    redirect_to deck_path(@deck), notice: "피처드를 해제했습니다."
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
