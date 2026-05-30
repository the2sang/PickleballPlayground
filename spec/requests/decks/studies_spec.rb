require "rails_helper"

RSpec.describe "Decks::Studies", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }

  before { sign_in(user) }

  describe "GET /decks/:deck_id/study" do
    context "빈 덱 (카드 없음)" do
      it "세션 완료 화면을 즉시 렌더" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습 완료")
      end
    end

    context "due 없음 (카드 있지만 모두 미래 예정)" do
      before do
        card = create(:card, deck: deck)
        create(:card_review, :mature, user: user, card: card)
      end

      it "세션 완료 화면을 즉시 렌더" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습 완료")
      end
    end

    context "due 카드 있음" do
      before do
        card = create(:card, deck: deck)
        create(:card_review, :due, user: user, card: card)
      end

      it "학습 화면을 렌더 (완료 화면 아님)" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("오늘의 학습 완료")
      end
    end

    context "새 카드 있음 (CardReview 미생성)" do
      before { create(:card, deck: deck) }

      it "학습 화면을 렌더 (새 카드는 due로 취급)" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("오늘의 학습 완료")
      end
    end

    context "비인증 사용자" do
      before { delete session_path }

      it "로그인 페이지로 리다이렉트" do
        get deck_study_path(deck)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
