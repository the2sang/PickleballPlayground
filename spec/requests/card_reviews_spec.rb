# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardReviews", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user) }
  let(:deck)    { create(:deck, :personal, owner: user) }
  let(:card)    { create(:card, deck: deck) }
  let(:headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  describe "POST /card_reviews" do
    context "인증된 본인 덱 카드 평가" do
      before { sign_in(user) }

      it "rating=3 평가 시 CardReview를 생성하고 Turbo Stream으로 응답한다" do
        expect {
          post card_reviews_path,
            params: { card_review: { card_id: card.id, deck_id: deck.id, rating: 3 } },
            headers: headers
        }.to change(CardReview, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("study-card")
      end

      it "Turbo Stream으로 #study-card를 다음 카드 또는 complete partial로 replace한다" do
        # 추가 카드 없으면 complete 렌더 검증
        post card_reviews_path,
          params: { card_review: { card_id: card.id, deck_id: deck.id, rating: 3 } },
          headers: headers
        expect(response.body).to include("turbo-stream").and include("study-card")
        expect(response.body).to include("오늘의 학습 완료")  # complete partial
      end

      it "두 번째 due 카드가 있으면 complete가 아닌 _card partial로 replace" do
        # next_card 추가 — 평가 후 큐에 남는 카드가 있도록
        create(:card, deck: deck, position: 2)
        post card_reviews_path,
          params: { card_review: { card_id: card.id, deck_id: deck.id, rating: 3 } },
          headers: headers
        expect(response.body).to include("turbo-stream")
        expect(response.body).not_to include("오늘의 학습 완료")
      end

      it "동일 카드 더블 submit 시 단일 CardReview만 유지 (멱등성)" do
        2.times do
          post card_reviews_path,
            params: { card_review: { card_id: card.id, deck_id: deck.id, rating: 3 } },
            headers: headers
        end
        expect(CardReview.where(user: user, card: card).count).to eq(1)
      end

      it "out-of-range rating (5)은 422 응답 (T-03-02 / CR-02)" do
        post card_reviews_path,
          params: { card_review: { card_id: card.id, deck_id: deck.id, rating: 5 } },
          headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "타 사용자 카드 평가 시도 (T-03-01)" do
      before { sign_in(user) }

      let(:foreign_deck) { create(:deck, :personal, owner: other) }
      let(:foreign_card) { create(:card, deck: foreign_deck) }

      it "CardReviewPolicy가 거부하여 root_path로 리다이렉트" do
        expect {
          post card_reviews_path,
            params: { card_review: { card_id: foreign_card.id, deck_id: foreign_deck.id, rating: 3 } }
        }.not_to change(CardReview, :count)
        expect(response).to redirect_to(root_path).or have_http_status(:forbidden)
      end
    end

    context "비인증 사용자" do
      it "로그인 페이지로 리다이렉트" do
        post card_reviews_path,
          params: { card_review: { card_id: card.id, deck_id: deck.id, rating: 3 } }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "타 사용자 카드에 deck_id 없이 평가 시도 (T-03-IDOR / CR-01)" do
      before { sign_in(user) }

      let(:other_user)   { create(:user) }
      let(:foreign_deck) { create(:deck, :personal, owner: other_user) }
      let(:foreign_card) { create(:card, deck: foreign_deck) }

      it "Spec A: CardReview가 생성되지 않고 차단된다 (IDOR 차단)" do
        expect {
          post card_reviews_path,
            params: { card_review: { card_id: foreign_card.id, rating: 3 } },
            headers: headers
        }.not_to change(CardReview, :count)
        expect(response).to redirect_to(root_path).or have_http_status(:forbidden)
      end

      it "Spec B: 본인 덱 카드를 deck_id 없이 평가해도 성공한다 (회귀 방지)" do
        expect {
          post card_reviews_path,
            params: { card_review: { card_id: card.id, rating: 3 } },
            headers: headers
        }.to change(CardReview, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("study-card")
      end
    end
  end
end
