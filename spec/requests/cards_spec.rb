require "rails_helper"

RSpec.describe "Cards", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  describe "POST /decks/:deck_id/cards (CARD-01)" do
    context "인증된 본인 덱에 카드 생성" do
      before { sign_in(user) }

      it "카드를 생성하고 Turbo Stream으로 응답한다" do
        expect {
          post deck_cards_path(deck),
            params: { card: { front: "앞면", back: "뒷면", hint: "힌트", tags: "태그1" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Card, :count).by(1)
        expect(response).to have_http_status(:ok)
      end

      it "비인증 시 redirect" do
        sign_out
        post deck_cards_path(deck),
          params: { card: { front: "앞면", back: "뒷면" } }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "front_image 파라미터를 무시한다 (CARD-06, T-02-03)" do
      before { sign_in(user) }

      it "front_image를 전송해도 attach가 일어나지 않는다" do
        fake_image = Rack::Test::UploadedFile.new(
          StringIO.new("fake image data"),
          "image/png",
          original_filename: "test.png"
        )
        post deck_cards_path(deck),
          params: { card: { front: "앞면", back: "뒷면", front_image: fake_image } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        card = Card.last
        expect(card).not_to be_nil
        expect(card.front_image).not_to be_attached
      end
    end
  end

  describe "GET /decks/:deck_id/cards/:id/edit (CARD-02)" do
    let!(:card) { create(:card, deck: deck) }

    context "인증된 본인 덱 카드 편집" do
      before { sign_in(user) }

      it "Turbo Frame 응답으로 편집 폼을 렌더링한다" do
        get edit_deck_card_path(deck, card),
          headers: { "Turbo-Frame" => "card_#{card.id}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("card_#{card.id}")
      end

      it "타인 덱 카드 편집 시도 시 404" do
        other_deck = create(:deck, scope: :personal, owner: other_user)
        other_card = create(:card, deck: other_deck)

        get edit_deck_card_path(other_deck, other_card)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /decks/:deck_id/cards/:id (CARD-03)" do
    let!(:card) { create(:card, deck: deck) }

    context "인증된 본인 덱 카드 수정" do
      before { sign_in(user) }

      it "카드 수정 시 Turbo Stream으로 행 교체" do
        patch deck_card_path(deck, card),
          params: { card: { front: "수정된 앞면", back: "수정된 뒷면" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(card.reload.front).to eq("수정된 앞면")
      end

      it "검증 실패 시 422 응답과 에러 메시지" do
        patch deck_card_path(deck, card),
          params: { card: { front: "", back: "" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "타인 덱 카드 수정 시도" do
      before { sign_in(other_user) }

      it "404를 반환한다" do
        patch deck_card_path(deck, card),
          params: { card: { front: "수정된 앞면", back: "수정된 뒷면" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /decks/:deck_id/cards/:id (CARD-04)" do
    let!(:card) { create(:card, deck: deck) }

    context "인증된 본인 덱 카드 삭제" do
      before { sign_in(user) }

      it "카드와 CardReview를 cascade 삭제한다" do
        create(:card_review, card: card)

        expect {
          delete deck_card_path(deck, card),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Card, :count).by(-1)
          .and change(CardReview, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  def sign_out
    delete session_path
  end
end
