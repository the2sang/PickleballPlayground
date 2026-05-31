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

      it "덱스왑 왼편에서 난이도별 학습 메뉴와 1~5개 별 이상 링크를 제공한다" do
        get deck_flip_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("난이도별 학습")

        (1..5).each do |n|
          expect(response.body).to include("별 #{n}개 이상")
          expect(response.body).to include(deck_flip_path(deck, min_stars: n))
        end
      end
    end

    context "min_stars 필터" do
      let!(:rated_card)   { create(:card, deck: deck) }
      let!(:low_card)     { create(:card, deck: deck) }
      let!(:unrated_card) { create(:card, deck: deck) }

      before do
        create(:user_card_rating, user: user, card: rated_card, difficulty: 4)
        create(:user_card_rating, user: user, card: low_card, difficulty: 2)
      end

      it "4이상 별점 카드 front를 JSON에 포함" do
        get deck_flip_path(deck, min_stars: 4)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(rated_card.front)
        expect(response.body).not_to include(low_card.front)
        expect(response.body).not_to include(unrated_card.front)
      end

      it "3개 이상만 선택하면 난이도 3 이상으로 평가한 카드만 포함한다" do
        get deck_flip_path(deck, min_stars: 3)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(rated_card.front)
        expect(response.body).not_to include(low_card.front)
        expect(response.body).not_to include(unrated_card.front)
      end
    end

    context "비인증 사용자" do
      before { delete session_path }  # 로그아웃

      it "공식 덱의 주관식 풀이 페이지에 접근할 수 있다" do
        official_deck = create(:deck, :official)
        create(:card, deck: official_deck)

        get deck_flip_path(official_deck)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("주관식 학습")
        expect(response.body).to include("flip-card")
      end
    end
  end
end
