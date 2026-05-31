# frozen_string_literal: true

class CardReviewsController < ApplicationController
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
      StudySessionAnswer.create!(
        study_session: @study_session,
        card:          @card,
        rating:        rating,
        is_correct:    rating >= 3
      )
    end

    Flashcards::DueCountCacheService.invalidate(Current.user)

    due_remaining = if @study_session&.repeat?
                      answered_ids = @study_session.study_session_answers.pluck(:card_id)
                      @deck.cards.where.not(id: answered_ids)
    else
                      Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
    end

    @next_card = due_remaining.first

    if @next_card.nil?
      if @study_session
        total   = @study_session.study_session_answers.count
        correct = @study_session.study_session_answers.where(is_correct: true).count
        @study_session.complete!(total: total, correct: correct)
        redirect_to deck_study_session_path(@deck, @study_session), status: :see_other
      else
        redirect_to deck_path(@deck), status: :see_other
      end
      return
    end

    @options         = @next_card.quiz_options(@deck)
    @total_count     = @deck.cards.count
    @completed_count = @study_session ? @study_session.study_session_answers.count : 0

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(root_path) }
    end
  end
end
