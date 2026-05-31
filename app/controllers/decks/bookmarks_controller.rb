class Decks::BookmarksController < ApplicationController
  before_action :set_deck
  after_action :verify_authorized

  def create
    @bookmark = Current.user.deck_bookmarks.find_or_initialize_by(deck: @deck)
    authorize @bookmark
    @bookmark.save! unless @bookmark.persisted?

    redirect_back_or_to decks_path, notice: "북마크에 추가했습니다."
  end

  def destroy
    @bookmark = Current.user.deck_bookmarks.find_by!(deck: @deck)
    authorize @bookmark
    @bookmark.destroy!

    redirect_back_or_to decks_path, notice: "북마크를 해제했습니다."
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
