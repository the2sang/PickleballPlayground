# frozen_string_literal: true

class Decks::StudyCardsController < ApplicationController
  include Flashcards::StudyNavigation

  before_action :set_deck
  before_action :set_study_session

  def show
    authorize @deck, :show?

    card_ids = study_card_ids(@study_session)
    @current_card = @deck.cards.find(params[:card_id])
    @current_index = card_ids.index(@current_card.id)

    unless @current_index
      redirect_to deck_study_path(@deck), alert: "학습 세션에 포함되지 않은 카드입니다."
      return
    end

    answer = @study_session.study_session_answers.find_by(card: @current_card)

    @options = study_options_for(@study_session, @deck, @current_card)
    @total_count = card_ids.size
    @completed_count = @study_session.study_session_answers.count
    @answered_rating = answer&.rating
    @selected_answer = answer&.selected_answer.to_s
    @previous_card_path = navigation_path(card_ids[@current_index - 1]) if @current_index.positive?
    @next_card_path = navigation_path(card_ids[@current_index + 1]) if @current_index < card_ids.size - 1

    respond_to do |format|
      format.turbo_stream
      format.html { render "decks/studies/show" }
    end
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def set_study_session
    @study_session = StudySession.find_by!(
      id: params[:study_session_id],
      user: Current.user,
      deck: @deck
    )
  end

  def navigation_path(card_id)
    deck_study_session_card_path(@deck, @study_session, card_id)
  end
end
