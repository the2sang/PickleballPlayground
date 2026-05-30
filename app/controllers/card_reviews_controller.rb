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

    # Step 4: Load and authorize deck BEFORE calling service (T-03-03 defense)
    # T-03-01 protection: DeckPolicy#show? blocks access to decks the user doesn't own
    # This must run before SubmitReviewService to prevent CardReview creation for foreign decks
    if params[:card_review][:deck_id].present?
      @deck = Deck.find(params[:card_review][:deck_id])
      authorize @deck, :show?
    end

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
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html { redirect_back_or_to(root_path, alert: "잘못된 평가입니다.") }
      end
      return
    end

    if result.success?
      # Step 7: Fetch next due card for Turbo Stream swap
      @next_card = @deck ? Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call.first : nil
      respond_to do |format|
        format.turbo_stream  # -> app/views/card_reviews/create.turbo_stream.erb
        format.html { redirect_back_or_to(root_path) }
      end
    else
      flash.now[:alert] = result.errors.join(", ")
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html { redirect_back_or_to(root_path, alert: result.errors.join(", ")) }
      end
    end
  end

  private

  def card_review_params
    params.require(:card_review).permit(:card_id, :rating, :deck_id)
    # 명시적 제외:
    #   :front_image, :back_image — D-20 (image params blocked at CardsController, never here)
    # policy_scope 금지 — D-19
  end
end
