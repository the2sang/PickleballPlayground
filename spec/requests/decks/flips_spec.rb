require "rails_helper"

RSpec.describe "Decks::Flips", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }

  before { sign_in(user) }

  describe "GET /decks/:deck_id/flip" do
    context "카드 없음" do
      it "200 반환" do
        get deck_flip_path(deck)
        expect(response).to have_http_status(:ok)
      end
    end

    context "카드 있음" do
      before { create_list(:card, 3, deck: deck) }

      it "200 반환 및 flip-card 컨트롤러 포함" do
        get deck_flip_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("flip-card")
      end
    end

    context "min_stars 필터" do
      let!(:rated_card)   { create(:card, deck: deck) }
      let!(:unrated_card) { create(:card, deck: deck) }

      before do
        create(:user_card_rating, user: user, card: rated_card, difficulty: 4)
      end

      it "4이상 별점 카드 front를 JSON에 포함" do
        get deck_flip_path(deck, min_stars: 4)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(rated_card.front)
        expect(response.body).not_to include(unrated_card.front)
      end
    end

    context "비인증 사용자" do
      before { delete session_path }  # 로그아웃

      it "로그인 페이지로 리다이렉트" do
        get deck_flip_path(deck)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
