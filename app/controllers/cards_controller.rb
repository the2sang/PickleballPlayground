class CardsController < ApplicationController
  before_action :set_deck
  before_action :set_card, only: %i[edit update destroy]
  before_action :set_can_edit
  after_action :verify_authorized

  def create
    @card = @deck.cards.build(card_params.merge(card_type: :basic))
    authorize @card
    if @card.save
      Flashcards::DueCountCacheService.invalidate(Current.user)
      @cards = @deck.cards.order(:position, :id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to deck_path(@deck), notice: "카드가 추가되었습니다." }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "deck-add-form-#{@deck.id}",
            partial: "decks/card_add_form",
            locals: { deck: @deck, card: @card }
          ), status: :unprocessable_entity
        }
        format.html { render "decks/show", status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @card
  end

  def update
    authorize @card
    if @card.update(card_params)
      Flashcards::DueCountCacheService.invalidate(Current.user)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to deck_path(@deck) }
      end
    else
      render turbo_stream: turbo_stream.replace(
        "card_#{@card.id}",
        partial: "decks/card_edit_form",
        locals: { card: @card, deck: @deck }
      ), status: :unprocessable_entity
    end
  end

  def destroy
    authorize @card
    @card.destroy!
    Flashcards::DueCountCacheService.invalidate(Current.user)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to deck_path(@deck) }
    end
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end

  def set_can_edit
    @can_edit = policy(@deck).update?
  end

  def set_card
    @card = @deck.cards.find(params[:id])
  end

  def card_params
    params.require(:card).permit(:front, :back, :hint, :tags)
    # 명시적 제외:
    #   :front_image, :back_image    — T-02-03 (CONTEXT.md Decision #6)
    #   :card_type                   — 컨트롤러에서 :basic 강제 (v1)
    #   :deck_id, :position          — 경로/모델이 결정
    #   :owner_id, :owner_type       — Deck의 책임
  end
end
