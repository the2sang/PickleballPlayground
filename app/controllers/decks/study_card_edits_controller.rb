# frozen_string_literal: true

class Decks::StudyCardEditsController < ApplicationController
  include Flashcards::StudyNavigation
  include Flashcards::CardStudyState

  before_action :set_deck
  before_action :set_card
  after_action :verify_authorized

  def update
    authorize @card, :update?
    prepare_study_context

    if @card.update(study_card_params)
      Flashcards::DueCountCacheService.invalidate(Current.user)
      set_card_study_state(@card)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to deck_study_path(@deck), notice: "문제가 수정되었습니다." }
      end
    else
      prepare_failed_card_state
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_entity }
        format.html { redirect_to deck_study_path(@deck), alert: @card.errors.full_messages.to_sentence }
      end
    end
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def set_card
    @card = @deck.cards.find(params[:card_id])
  end

  def prepare_study_context
    if params[:study_session_id].present?
      @study_session = StudySession.find_by(
        id: params[:study_session_id],
        user: Current.user,
        deck: @deck
      )
    end

    if @study_session
      card_ids = study_card_ids(@study_session)
      @current_index = card_ids.index(@card.id) || params[:current_index].to_i
      @total_count = card_ids.size
      @completed_count = @study_session.study_session_answers.count
      @previous_card_path = navigation_path(card_ids[@current_index - 1]) if @current_index.positive?
      @next_card_path = navigation_path(card_ids[@current_index + 1]) if @current_index < card_ids.size - 1

      answer = @study_session.study_session_answers.find_by(card: @card)
      @answered_rating = answer&.rating
      @selected_answer = answer&.selected_answer.to_s
    else
      @current_index = params[:current_index].to_i
      @total_count = params[:total_count].to_i
      @completed_count = params[:completed_count].to_i
    end

    @options = study_options_for(@study_session, @deck, @card)
  end

  def prepare_failed_card_state
    set_card_study_state(@card)
    @edit_mode = true
    @options = ([ @card.back ] + @card.answer_choices.first(3)).shuffle
  end

  def navigation_path(card_id)
    deck_study_session_card_path(@deck, @study_session, card_id) if card_id
  end

  def study_card_params
    permitted = params.require(:card).permit(:front, answer_choices: [])
    permitted[:answer_choices] = sanitized_answer_choices(permitted[:answer_choices]) if permitted.key?(:answer_choices)
    permitted
  end

  def sanitized_answer_choices(values)
    Array(values).map(&:to_s).map(&:strip).reject { |value| value.blank? || value == @card.back }.first(3)
  end
end
