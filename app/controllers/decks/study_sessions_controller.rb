class Decks::StudySessionsController < ApplicationController
  before_action :set_deck
  before_action :set_session

  def show
    authorize @study_session
    @correct_answers   = @study_session.study_session_answers
                                       .where(is_correct: true)
                                       .includes(:card)
                                       .order(:created_at)
    @incorrect_answers = @study_session.study_session_answers
                                       .where(is_correct: false)
                                       .includes(:card)
                                       .order(:created_at)
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def set_session
    @study_session = StudySession.find(params[:id])
  end
end
