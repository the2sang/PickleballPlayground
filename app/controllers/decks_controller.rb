class DecksController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_deck, only: %i[show edit update destroy]
  before_action :authorize_deck!, only: %i[edit update destroy]

  def index
    @official_decks = Deck.where(scope: :official).includes(:cards).order(:created_at)

    if authenticated?
      @personal_decks = Deck.where(scope: :personal, owner: Current.user)
                            .includes(:cards)
                            .order(updated_at: :desc)
      approved_club_ids = Current.user.club_memberships.approved.pluck(:club_id)
      @show_club_section = approved_club_ids.any?
      @club_decks = @show_club_section ?
        Deck.where(scope: :club, owner_type: "Club", owner_id: approved_club_ids)
            .includes(:cards).order(updated_at: :desc) : []

      all_deck_ids = (@official_decks + @personal_decks + @club_decks).map(&:id)
      @deck_session_stats = Flashcards::DeckSessionStatsQuery.new(
        user: Current.user, deck_ids: all_deck_ids
      ).call
    else
      @personal_decks = []
      @club_decks = []
      @show_club_section = false
      @deck_session_stats = {}
    end
  end

  def show
    authorize @deck
    @cards = @deck.cards.order(:position, :id)
  end

  def new
    @deck = Deck.new(scope: :personal, owner: Current.user)
    authorize @deck
  end

  def create
    @deck = Deck.new(deck_params.merge(scope: :personal, owner: Current.user))
    authorize @deck
    if @deck.save
      redirect_to @deck, notice: "덱이 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @deck.update(deck_params)
      redirect_to @deck, notice: "덱이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deck.destroy!
    redirect_to decks_path, notice: "덱이 삭제되었습니다."
  end

  private

  def set_deck
    @deck = Deck.find(params[:id])
  end

  def authorize_deck!
    authorize @deck
  end

  def deck_params
    params.require(:deck).permit(:title, :description)
    # owner/scope/owner_id/owner_type 명시 제외 — T-02-01 (mass assignment 차단)
  end
end
