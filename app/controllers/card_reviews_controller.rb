# frozen_string_literal: true

class CardReviewsController < ApplicationController
  def create
    @card = Card.find(params[:card_review][:card_id])

    # Step 2: Build CardReview with current user — ensures record.user == current_user
    # for CardReviewPolicy#create? to pass (T-03-01 guard)
    @card_review = CardReview.new(user: Current.user, card: @card)

    # Step 3: Authorize card_review — CardReviewPolicy#create? verifies record.user == user
    # Raises Pundit::NotAuthorizedError → ApplicationController → root_path redirect
    authorize @card_review

    # CR-01: never trust params[:deck_id] — derive deck from card itself to prevent IDOR.
    # This unconditional derivation ensures DeckPolicy#show? always gates cross-deck access
    # regardless of what deck_id (or lack thereof) the request payload contains.
    @deck = @card.deck
    authorize @deck, :show?

    # Step 5: Validate rating range — SubmitReviewService/Sm2Service raises ArgumentError
    # for ratings outside VALID_RATINGS = [1, 2, 3, 4]
    rating = params[:card_review][:rating].to_i

    # Step 6: Call service
    begin
      result = Flashcards::SubmitReviewService.call(
        user:    Current.user,
        card_id: @card.id,
        rating:  rating
      )
    rescue ArgumentError
      # T-03-02: invalid rating value (e.g. 0, 5, "abc".to_i=0)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("study-card", partial: "card_reviews/error"),
                 status: :unprocessable_entity
        end
        format.html { redirect_back_or_to(root_path, alert: "잘못된 평가입니다.") }
      end
      return
    end

    if result.success?
      due_remaining = Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
      @next_card = due_remaining.first
      if @next_card
        @options = @next_card.quiz_options(@deck)
        @total_count = @deck.cards.count
        @completed_count = @total_count - due_remaining.size
      end
      respond_to do |format|
        format.turbo_stream  # -> app/views/card_reviews/create.turbo_stream.erb
        format.html { redirect_back_or_to(root_path) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("study-card", partial: "card_reviews/error"),
                 status: :unprocessable_entity
        end
        format.html { redirect_back_or_to(root_path, alert: result.errors.join(", ")) }
      end
    end
  end
end
