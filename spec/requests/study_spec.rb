require "rails_helper"

RSpec.describe "Study (Global Queue)", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  describe "GET /study" do
    context "due 카드 없음 (덱 0개)" do
      before { sign_in(user) }

      it "글로벌 완료 화면을 렌더 (/decks 링크 + @deck 미참조)" do
        get study_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습을 모두 마쳤습니다")
        expect(response.body).to include("덱 목록으로")
        expect(response.body).to include(decks_path)
      end
    end

    context "personal 덱의 due 카드 있음" do
      let(:deck) { create(:deck, :personal, owner: user) }
      before do
        card = create(:card, deck: deck)
        create(:card_review, :due, user: user, card: card)
        sign_in(user)
      end

      it "학습 화면을 렌더 (완료 화면 아님)" do
        get study_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("오늘의 학습을 모두 마쳤습니다")
        expect(response.body).to include("study-card")
      end
    end

    context "official 덱의 신규 카드 있음" do
      let(:deck) { create(:deck, :official) }
      before do
        create(:card, deck: deck)
        sign_in(user)
      end

      it "학습 화면을 렌더 (신규 카드 = due)" do
        get study_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("오늘의 학습을 모두 마쳤습니다")
      end
    end

    context "club 덱 due 카드 (T-03-04 회귀 가드)" do
      let(:club_deck) { create(:deck, :club) }
      before do
        card = create(:card, deck: club_deck)
        create(:card_review, :due, user: user, card: card)
        sign_in(user)
      end

      it "club 덱 카드는 글로벌 큐에 노출되지 않는다 (완료 화면 렌더)" do
        get study_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습을 모두 마쳤습니다")
      end
    end

    context "타 사용자 personal 덱 due 카드" do
      let(:foreign_deck) { create(:deck, :personal, owner: other) }
      before do
        card = create(:card, deck: foreign_deck)
        create(:card_review, :due, user: other, card: card)
        sign_in(user)
      end

      it "타인 카드는 큐에 노출되지 않는다" do
        get study_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습을 모두 마쳤습니다")
      end
    end

    context "비인증 사용자" do
      it "로그인 페이지로 리다이렉트" do
        get study_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
