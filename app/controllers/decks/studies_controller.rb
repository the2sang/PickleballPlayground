class Decks::StudiesController < ApplicationController
  include Flashcards::StudyNavigation
  include Flashcards::CardStudyState

  before_action :set_deck

  def show
    authorize @deck, :show?

    repeat = params[:repeat].present?

    @due_cards = if repeat
                   @deck.cards
    else
                   Flashcards::StudyQueueQuery.new(user: Current.user, deck: @deck).call
    end

    # min_stars 필터 — 별점 등록 카드로 학습 범위 제한
    min_stars = params[:min_stars].to_i
    if min_stars.between?(1, 5)
      rated_ids = UserCardRating.where(user: Current.user, difficulty: min_stars..)
                                 .where(card: @deck.cards)
                                 .pluck(:card_id)
      @due_cards = @due_cards.where(id: rated_ids)
    end

    if params[:card_filter] == "bookmarked"
      bookmarked_ids = CardBookmark.where(user: Current.user, card: @deck.cards).pluck(:card_id)
      @due_cards = @due_cards.where(id: bookmarked_ids)
    end

    difficulty = params[:difficulty].to_i
    if difficulty.between?(1, 5)
      rated_ids = UserCardRating.where(user: Current.user, difficulty: difficulty)
                                 .where(card: @deck.cards)
                                 .pluck(:card_id)
      @due_cards = @due_cards.where(id: rated_ids)
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

    study_card_ids = @due_cards.pluck(:id)
    store_study_card_ids(@study_session, study_card_ids)

    @current_card    = Card.find(study_card_ids.first)
    @total_count     = study_card_ids.size
    @completed_count = 0
    @current_index   = 0
    @options         = study_options_for(@study_session, @deck, @current_card)
    set_card_study_state(@current_card)
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
