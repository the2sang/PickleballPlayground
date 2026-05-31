require "rails_helper"

RSpec.describe "Decks::CardRatings", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  before { sign_in(user) }

  describe "POST /decks/:deck_id/card_ratings" do
    context "신규 별점 생성" do
      it "200 반환 및 UserCardRating 1개 생성" do
        expect {
          post deck_card_ratings_path(deck),
               params: { card_id: card.id, difficulty: 3 },
               as: :json
        }.to change(UserCardRating, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(3)
      end
    end

    context "기존 별점 업데이트" do
      before { create(:user_card_rating, user: user, card: card, difficulty: 2) }

      it "200 반환 및 레코드 수 변화 없이 업데이트" do
        expect {
          post deck_card_ratings_path(deck),
               params: { card_id: card.id, difficulty: 5 },
               as: :json
        }.not_to change(UserCardRating, :count)
        expect(response).to have_http_status(:ok)
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(5)
      end
    end

    context "범위 초과 difficulty clamp" do
      it "9 → 5로 클램프" do
        post deck_card_ratings_path(deck),
             params: { card_id: card.id, difficulty: 9 },
             as: :json
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(5)
      end

      it "0 → 1로 클램프" do
        post deck_card_ratings_path(deck),
             params: { card_id: card.id, difficulty: 0 },
             as: :json
        expect(UserCardRating.find_by(user: user, card: card).difficulty).to eq(1)
      end
    end

    context "비인증 사용자" do
      before { delete session_path }

      it "로그인 페이지로 리다이렉트" do
        post deck_card_ratings_path(deck), params: { card_id: card.id, difficulty: 3 }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
