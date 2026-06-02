# frozen_string_literal: true

class CardReviewsController < ApplicationController
  include Flashcards::StudyNavigation
  include Flashcards::CardStudyState

  def create
    @card = Card.find(params[:card_review][:card_id])
    @card_review = CardReview.new(user: Current.user, card: @card)
    authorize @card_review

    @deck = @card.deck
    authorize @deck, :show?

    rating = params[:card_review][:rating].to_i

    @study_session = StudySession.find_by(
      id:   params[:card_review][:study_session_id],
      user: Current.user
    )

    begin
      result = Flashcards::SubmitReviewService.call(
        user:    Current.user,
        card_id: @card.id,
        rating:  rating
      )
    rescue ArgumentError
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("study-card", partial: "card_reviews/error"),
                 status: :unprocessable_entity
        end
        format.html { redirect_back_or_to(root_path, alert: "잘못된 평가입니다.") }
      end
      return
    end

    unless result.success?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("study-card", partial: "card_reviews/error"),
                 status: :unprocessable_entity
        end
        format.html { redirect_back_or_to(root_path, alert: result.errors.join(", ")) }
      end
      return
    end

    if @study_session
      answer = @study_session.study_session_answers.find_or_initialize_by(card: @card)
      answer.update!(
        rating:          rating,
        is_correct:      rating >= 3,
        selected_answer: params[:card_review][:selected_answer]
      )
    end

    Flashcards::DueCountCacheService.invalidate(Current.user)

    if @study_session
      card_ids = study_card_ids(@study_session)
      card_ids = @deck.cards.ordered.pluck(:id) if card_ids.empty?
      current_index = card_ids.index(@card.id) || 0
      next_index = current_index + 1
      @next_card = @deck.cards.find_by(id: card_ids[next_index])
    else
      card_ids = []
      next_index = 0
      @next_card = Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call.first
    end

    if @next_card.nil?
      if @study_session
        total   = card_ids.size
        correct = @study_session.study_session_answers.where(is_correct: true).count
        @study_session.complete!(total: total, correct: correct)
        redirect_to deck_study_session_path(@deck, @study_session), status: :see_other
      else
        redirect_to deck_path(@deck), status: :see_other
      end
      return
    end

    @options         = @study_session ? study_options_for(@study_session, @deck, @next_card) : @next_card.quiz_options(@deck)
    @total_count     = @study_session ? card_ids.size : @deck.cards.count
    @completed_count = @study_session ? @study_session.study_session_answers.count : 0
    @current_index   = next_index
    @previous_card_path = deck_study_session_card_path(@deck, @study_session, @card) if @study_session
    if @study_session && next_index < card_ids.size - 1
      @next_card_path = deck_study_session_card_path(@deck, @study_session, card_ids[next_index + 1])
    end
    set_card_study_state(@next_card)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(root_path) }
    end
  end
end
