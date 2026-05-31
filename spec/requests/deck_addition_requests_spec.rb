require "rails_helper"

RSpec.describe "DeckAdditionRequests", type: :request do
  describe "POST /deck_addition_requests" do
    it "creates a pending request when the user is at the personal deck limit" do
      user = create(:user)
      Deck::PERSONAL_DECK_LIMIT.times { |index| create(:deck, :personal, owner: user, title: "덱 #{index}") }
      sign_in(user)

      expect {
        post deck_addition_requests_path
      }.to change { DeckAdditionRequest.pending.where(user: user).count }.by(1)

      expect(response).to redirect_to(decks_path)
      expect(flash[:notice]).to include("덱 추가 승인요청")
    end

    it "does not create duplicate pending requests" do
      user = create(:user)
      Deck::PERSONAL_DECK_LIMIT.times { |index| create(:deck, :personal, owner: user, title: "덱 #{index}") }
      create(:deck_addition_request, user: user)
      sign_in(user)

      expect {
        post deck_addition_requests_path
      }.not_to change(DeckAdditionRequest, :count)

      expect(flash[:alert]).to include("처리 대기")
    end
  end
end
