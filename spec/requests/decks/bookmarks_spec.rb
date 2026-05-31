require "rails_helper"

RSpec.describe "Decks::Bookmarks", type: :request do
  let(:user) { create(:user) }

  describe "POST /decks/:deck_id/bookmark" do
    it "로그인 사용자가 접근 가능한 덱을 북마크한다" do
      sign_in(user)
      deck = create(:deck, :official)

      expect {
        post deck_bookmark_path(deck)
      }.to change(DeckBookmark, :count).by(1)

      expect(user.deck_bookmarks.last.deck).to eq(deck)
      expect(response).to redirect_to(decks_path)
    end

    it "이미 북마크한 덱은 중복 생성하지 않는다" do
      sign_in(user)
      deck = create(:deck, :official)
      create(:deck_bookmark, user: user, deck: deck)

      expect {
        post deck_bookmark_path(deck)
      }.not_to change(DeckBookmark, :count)

      expect(response).to redirect_to(decks_path)
    end

    it "볼 수 없는 개인 덱은 북마크하지 못한다" do
      sign_in(user)
      other_deck = create(:deck, :personal)

      expect {
        post deck_bookmark_path(other_deck)
      }.not_to change(DeckBookmark, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /decks/:deck_id/bookmark" do
    it "내 북마크를 해제한다" do
      sign_in(user)
      deck = create(:deck, :official)
      create(:deck_bookmark, user: user, deck: deck)

      expect {
        delete deck_bookmark_path(deck)
      }.to change(DeckBookmark, :count).by(-1)

      expect(response).to redirect_to(decks_path)
    end
  end
end
